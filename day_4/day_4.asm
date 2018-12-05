format PE64 console
entry start

include 'win64a.inc'

section '.data' data readable writeable

c_max_guards = 512
c_max_entries_per_guard = 512
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

align 8
struct GuardData
    num_entries dd ?
    entry_keys rd c_max_entries_per_guard
ends


g_guardData rb sizeof.GuardData * c_max_guards
g_guardIndexTable rd c_max_guards ; the guard id entry in this array indicies its index in the guarddata array
g_numGuards dd 0

struct ShiftBeginData
    guard_id dd ?
    packed_time dd ?
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

align 8
g_file_handle dq 0


section '.text' code readable executable

find_or_allocate_guard_idx:
    ; rcx = guard id 
    mov edx, [g_numGuards]
    mov rax, g_guardIndexTable ; rax = ptr
    
    lea r8, [rax + 4 * rdx] ; r8 = end 
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
        ret


read_next_line_into_buffer: ; tail call
    mov rcx, g_inputBuff 
    mov rdx, c_input_buff_size
    mov r8, [g_file_handle]
    jmp [fgets]



parse_time_and_guard_shift: ; if this string is a shift, add that shift and return 1. If it is anything else then return 0 (but we have parsed the time)
.c_stack_size = 32 + 8 * 4
    push rbp
    sub rsp, .c_stack_size
    mov rbp, rsp
    add rbp, 32

    mov rcx, g_inputBuff 
    mov rdx, _fscanf_begin_shift_specifier
    lea r8, [g_lastParsedData + ParsedData.month] 
    lea r9, [g_lastParsedData + ParsedData.day]

    mov rax, rbp
    mov qword [rax], g_lastParsedData
    add qword [rax], ParsedData.hour
    add rax, 8
    mov qword [rax], g_lastParsedData
    add qword [rax], ParsedData.minute
    add rax, 8
    mov qword [rax], g_lastParsedData
    add qword [rax], ParsedData.guard_id
    call [sscanf]

    ; we set midnight times to 1 and 11pm (23xx) to 0, so the sort ordering works out.
    cmp [g_lastParsedData + ParsedData.hour], 23
    jz @f
    ; time is 0
    mov [g_lastParsedData + ParsedData.hour], 1
    jmp .after_hour_fixup
@@:
    mov [g_lastParsedData + ParsedData.hour], 0

.after_hour_fixup:
    cmp rax, 5 ; = number of params for a shift
    jz .matched_new_shift
    xor rax, rax
    add rsp, .c_stack_size
    pop rbp
    ret

    .matched_new_shift:
        xor r9d, r9d
        pack_hour [g_lastParsedData + ParsedData.hour], r9d
        pack_minute [g_lastParsedData + ParsedData.minute], r9d
        pack_day [g_lastParsedData + ParsedData.minute], r9d
        pack_month [g_lastParsedData + ParsedData.minute], r9d
        mov [g_lastParsedData + ParsedData.packed_time], r9d

        mov ecx, [g_lastParsedData + ParsedData.guard_id]
        call find_or_allocate_guard_idx
        ; rax has guard index, load the guard data
        mov rcx, sizeof.GuardData
        mul ecx
        lea rax, [g_guardData + eax] ; rax has guard data ptr
        mov ecx, [rax + GuardData.num_entries] ; rcx = num entries in guard data
        add dword [rax + GuardData.num_entries], 1
        lea rdx, [GuardData.entry_keys + rcx * 4]
        add rdx, g_guardData ;
        mov dword [rdx], r9d

        add rsp, .c_stack_size
        pop rbp
        mov rax, 1
        ret

start:
.c_stack_size = 32
    push rbp
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
    mov ecx, [g_lastParsedData + ParsedData.packed_time]
    ; TODO -> NEXT! 
    start_from_here_next


.calculate_best_guard_time:
; todo

.end:
    mov rcx, _printf_message_fmt
    mov edx, 0
    call [printf] 

    mov rcx, [g_file_handle]
    test rcx, rcx
    jz .ret_main
    call [fclose]

.ret_main:
    add rsp, .c_stack_size
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
        fseek,'fseek'\

    include 'api\kernel32.inc'
    include 'api\user32.inc'