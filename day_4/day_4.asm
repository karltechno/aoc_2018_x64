format PE64 console
entry start

include 'win64a.inc'

section '.data' data readable writeable

c_max_guards = 512
c_max_entries_per_guard = 1024
c_input_buff_size = 256

; For each guard, we read in guard data and append packed integer keys for their times. Then we sort and can calculate sleeping schedules.

; Encoding scheme: 
; - Years are all the same, we can skip those
; - A series of sleep and wake up are sequential, so we can infer wake up and fall asleep from the sort ordering
; - 5 bits for month
; - 5 bits for day
; - 5 bits for hour ; actually we could do with just 1, since all times are 00 or 23. w/e
; - 6 bits for minute
; - total of 21 bits.
; h = hour; m = minute; M = month; guard shift = S; x = zeroes
; xxxxxxxxxxMMMMMdddddhhhhhmmmmmm
; ^ msb

c_minuteBits = 6
c_minuteMask = 63

c_hourBits = 5
c_hourShift = c_minuteBits
c_hourMask = 31

c_dayBits = 5
c_dayShift = c_hourShift + c_hourBits
c_dayMask = 31

c_monthBits = 5
c_monthShift = c_dayShift + c_dayBits
c_monthMask = 31


macro pack_minute min, bitfield {
    and min, c_minuteMask
    or bitfield, min
}

macro pack_hour hour, bitfield {
    and hour, c_hourMask
    shl hour, c_hourShift
    or bitfield, hour
}

macro pack_month month, bitfield {
    and month, c_monthMask
    shl month, c_monthShift
    or bitfield, month
}

macro pack_day day, bitfield {
    and day, c_dayMask
    shl day, c_dayShift
    or bitfield, day
}

align 4
struct GuardData
    guard_id dd ?
    num_entries dd ?
    entry_keys rd c_max_entries_per_guard
ends


g_guardData rd (sizeof.GuardData * c_max_guards) / 4
g_guardIndexTable rd c_max_guards ; the guard id entry in this array indicies its index in the guarddata array
g_numGuards dd 0

g_minuteAccumArray rd 60

struct ShiftBeginData
    guard_id dd ?
    packed_time dd ?
ends

struct GuardSleepData
    guard_id dd ?
    total_mins_sleep dd ?
    highest_sleep_min dd ?
ends


g_shiftBeginArray rb 16 * c_max_guards * sizeof.ShiftBeginData ; array of shift begin times to match up times to
g_numShiftBeginTimes dd 0

g_inputBuff rb c_input_buff_size

_filename db 'day_4_input.txt', 0
_fopen_mode db 'r', 0
_fscanf_begin_shift_specifier db '[1518-%d-%d %d:%d] Guard #%d', 0 ; yes I know I hardcoded the year here

_printf_message_fmt db 'The laziest guard is: %d', 0xA, 0

struct ParsedData
    guard_id dd ?
    minute dd ?
    hour dd ?
    day dd ?
    month dd ?
    packed_time dd ?
ends

g_lastParsedData ParsedData ?

g_bestGuardSleepData GuardSleepData ?
g_currentGuardSleepData GuardSleepData ?

align 8
g_file_handle dq 0


section '.text' code readable executable

insertion_sort_u32: ; rcx = pointer, rdx = num
    xor rax, rax
    push rbx
    push rdi

.outer:
    add rax, 1
    cmp rdx, rax 
    jbe .finish
    mov r8, rax

.inner:
    mov ebx, dword [rcx + r8 * 4]

    mov r10, r8
    sub r10, 1

    mov edi, dword [rcx + r10 * 4]

    cmp ebx, edi
    ja .outer

	; swap
    mov dword [rcx + r8 * 4], edi
    mov dword [rcx + r10 * 4], ebx
	
    sub r8, 1
    test r8, r8
    jz .outer
    jmp .inner

.finish:
	pop rdi
	pop rbx
	ret





find_or_allocate_guard_idx:
    ; rcx = guard id 
    mov edx, [g_numGuards]
    mov rax, g_guardIndexTable ; rax = ptr
    
    lea r8, [g_guardIndexTable + 4 * rdx] ; r8 = end 
@@: cmp rax, r8
    jz .alloc_new
    cmp ecx, dword [rax]
    jz .found_old
    add rax, 4
    jmp @r

    .found_old:
        ; in rax
        sub rax, g_guardIndexTable
        shr rax, 2 ; divide by dword size
        ret
    .alloc_new:
        mov dword [r8], ecx
        add [g_numGuards], 1
        
        mov rax, rdx ; rdx has num guards before
        ; set the guard id in guard data
        mov r9, sizeof.GuardData
        mul r9
        mov [g_guardData + GuardData.guard_id + rax], ecx
        mov eax, [g_numGuards]
        sub eax, 1
        ret


read_next_line_into_buffer: ; tail call
    mov rcx, g_inputBuff 
    mov rdx, c_input_buff_size
    mov r8, [g_file_handle]
    jmp [fgets]



parse_time_and_guard_shift: ; if this string is a shift, add that shift and return 1. If it is anything else then return 0 (but we have parsed the time)
.c_stack_size = 32 + 8 * 5
    push rbp

    sub rsp, .c_stack_size
    mov rbp, rsp
    add rbp, 32

    mov rcx, g_inputBuff 
    mov rdx, _fscanf_begin_shift_specifier
    lea r8, [g_lastParsedData.month] 
    lea r9, [g_lastParsedData.day]

    mov rax, rbp
    mov qword [rax], g_lastParsedData.hour
    mov qword [rax + 8], g_lastParsedData.minute
    mov qword [rax + 16], g_lastParsedData.guard_id
    call [sscanf]

    ; we set midnight times to 0 and 11pm (23xx) to 1, so the sort ordering works out.
    cmp [g_lastParsedData.hour], 23
    jz @f
    ; time is 0
    mov [g_lastParsedData.hour], 0
    jmp .after_hour_fixup
@@:
    mov [g_lastParsedData.hour], 1

.after_hour_fixup:
    xor r9d, r9d
    pack_hour [g_lastParsedData.hour], r9d
    pack_minute [g_lastParsedData.minute], r9d
    pack_day [g_lastParsedData.day], r9d
    pack_month [g_lastParsedData.month], r9d
    mov [g_lastParsedData.packed_time], r9d

    mov r8, 0
    cmp rax, 5 ; = number of params for a shift
    cmovnz rax, r8
    add rsp, .c_stack_size
    pop rbp
    ret


add_time_to_guard_data: ; rcx = guard idx, ; rdx = time
    mov r9, rdx
    mov rax, rcx
    mov ecx, sizeof.GuardData
    mul ecx
    lea r8, [g_guardData + eax] ; r8 has guard data ptr
    mov ecx, [r8 + GuardData.num_entries] ; rcx = num entries in guard data
    add dword [r8 + GuardData.num_entries], 1
    lea rdx, [rcx * 4 + GuardData.entry_keys]
    add rdx, r8 ;
    mov dword [rdx], r9d
    ret

start:
.c_stack_size = 32
    push rbp
    push rdi
    push rsi
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbp, rsp
    sub rsp, .c_stack_size

    mov rcx, _filename
    mov rdx, _fopen_mode
    call [fopen]

    test rax, rax
    jz .ret_main
    mov [g_file_handle], rax

; first we need to read all the shift starts
.read_next_shift_loop:
    call read_next_line_into_buffer
    test rax, rax
    jz .finished_read_all_shifts
    call parse_time_and_guard_shift
    test rax, rax
    jz .read_next_shift_loop ; not a valid shift

    mov edx, [g_numShiftBeginTimes]
    lea rcx, [g_shiftBeginArray + rdx * sizeof.ShiftBeginData] ; always add a new timing shift
    mov r8d, [g_lastParsedData + ParsedData.packed_time]
    mov [rcx + ShiftBeginData.packed_time], r8d
    mov r9d, [g_lastParsedData + ParsedData.guard_id]
    mov [rcx + ShiftBeginData.guard_id], r9d 
    add [g_numShiftBeginTimes], 1
    jmp .read_next_shift_loop


.finished_read_all_shifts: ; done with shifts, now we can loop through everything else and append the other times
    mov rcx, [g_file_handle]
    xor rdx, rdx
    xor r8, r8 ; SEEK_SET
    call [fseek]

.read_next_sleep_time: 
    call read_next_line_into_buffer
    test rax, rax
    jz .calculate_best_guard_time
    call parse_time_and_guard_shift
    test rax, rax ; 1 = a new shift, we don't care about that here
    jnz .read_next_sleep_time
    ; now we have to find which guard this time is connected to. We find the shortest time greater than this time.
    mov ecx, [g_lastParsedData + ParsedData.packed_time] ; ecx our packed time
    mov eax, [g_numShiftBeginTimes]
    mov rdx, g_shiftBeginArray ; rdx = current shift array ptr
    lea rax, [g_shiftBeginArray + rax * sizeof.ShiftBeginData] ; rax = shift array end
    xor r8d, r8d ; r8 = best guard id
    mov r9d, 0 ; r9 = shortest time

macro test_all_shift_loop_incr_loop {
    add rdx, sizeof.ShiftBeginData
    jmp .test_all_shift_times_loop
}

.test_all_shift_times_loop:
    cmp rax, rdx
    jz .finalize_sleep_guard_idx
    mov r10d, [rdx + ShiftBeginData.packed_time]
    mov r11d, r10d
    mov r12d, ecx
    sub r12d, r10d ; r12 = packed time copy 
    ja .check_best_sleep_time
    test_all_shift_loop_incr_loop

.check_best_sleep_time:
    cmp r9d, r10d
    jb .update_best_time
    test_all_shift_loop_incr_loop

.update_best_time:
    mov r8d, [rdx + ShiftBeginData.guard_id]
    mov r9d, r10d
    test_all_shift_loop_incr_loop

.finalize_sleep_guard_idx:
    cmp r9d, 0xFFFFFFFF
    jnz @f
    ud2 ; programmer error / bad data (could not find a shift/guard for this sleep time)
@@: mov ecx, r8d
    call find_or_allocate_guard_idx
    mov rcx, rax
    mov edx, [g_lastParsedData.packed_time]
    call add_time_to_guard_data
    jmp .read_next_sleep_time 

.calculate_best_guard_time:
    ; loop over each guard
    mov eax, [g_numGuards]
    mov r13, sizeof.GuardData 
    mul r13d
    add rax, g_guardData
    mov r12, rax ; r12 = end ptr
    mov rdi, g_guardData ; rdi = current ptr

.calc_time_outer:
    cmp r12, rdi
    jz .end

    mov edx, [rdi + GuardData.guard_id]
    mov [g_currentGuardSleepData.guard_id], edx
    mov [g_currentGuardSleepData.total_mins_sleep], 0
    mov [g_currentGuardSleepData.highest_sleep_min], 0
    mov rcx, g_minuteAccumArray
    mov rdx, 0
    mov r8, 4 * 60 
    call [memset] ; no volatile regs in above loop.
    
    mov edx, [rdi + GuardData.num_entries]
    test edx, edx
    jz .calc_time_outer_loop_next
    lea rcx, [rdi + GuardData.entry_keys]
    call insertion_sort_u32
    ; now keys are sorted, we can calculate the total time. 
    mov edx, [rdi + GuardData.num_entries]
    lea rcx, [rdi + GuardData.entry_keys]
    xor r14, r14 ; r14 = inner loop counter

.calc_time_inner:
    mov r15d, dword [rcx + r14 * 4]
    add r14d, 1
    mov r11d, dword [rcx + r14 * 4]
    add r14d, 1

    and r15d, c_minuteMask
    mov r10d, r15d ; r10d = first entry copy
    and r11d, c_minuteMask
    
    sub r11d, r15d  ; should
    add [g_currentGuardSleepData.total_mins_sleep], r11d
    add r11d, r15d

; add times to accum buffer
@@: add [g_minuteAccumArray + r10d * 4], 1
    add r10d, 1
    cmp r10d, r11d
    jnz @r

    cmp r14d, edx
    jnz .calc_time_inner

    ; check if this time is better
    mov r15d, [g_currentGuardSleepData.total_mins_sleep]
    cmp r15d, [g_bestGuardSleepData.total_mins_sleep]
    jna .calc_time_outer_loop_next
    ; this time is better, need to find the best minute
    mov [g_bestGuardSleepData.total_mins_sleep], r15d
    mov r15d, [g_currentGuardSleepData.guard_id]
    mov [g_bestGuardSleepData.guard_id], r15d

    xor r15, r15
    xor eax, eax ; rax = best min accum
    xor r14d, r14d

@@: cmp eax, dword [g_minuteAccumArray + r15 * 4]
    cmovb r14d, r15d
    cmovb eax, dword [g_minuteAccumArray + r15 * 4]
    add r15, 1
    cmp r15, 60
    jnz @r

    mov [g_bestGuardSleepData.highest_sleep_min], r14d
    
.calc_time_outer_loop_next:
    add rdi, sizeof.GuardData
    jmp .calc_time_outer

.end:
    mov rcx, _printf_message_fmt
    mov eax, [g_bestGuardSleepData.highest_sleep_min]
    mov edx, [g_bestGuardSleepData.guard_id]
    mul edx
    mov edx, eax

    call [printf] 

    mov rcx, [g_file_handle]
    test rcx, rcx
    jz .ret_main
    call [fclose]

.ret_main:
    add rsp, .c_stack_size

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rsi
    pop rdi
    pop rbp
    xor eax, eax
    ret


section '.idata' import data readable writeable

    library kernel32,'KERNEL32.DLL',\
	    user32,'USER32.DLL',\
        msvcrt,'MSVCRT.dll'

    import msvcrt,\
        fopen,'fopen',\
        fclose,'fclose',\
        sscanf,'sscanf',\
        printf,'printf',\
        fgets,'fgets',\
        fseek,'fseek',\
        memset,'memset'\

    include 'api\kernel32.inc'
    include 'api\user32.inc'
