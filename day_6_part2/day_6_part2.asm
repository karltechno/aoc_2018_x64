format PE64 console
entry start

include 'win64a.inc'

section '.data' data readable writeable

_filename db 'day_6_input.txt', 0
_fopen_mode db 'r', 0

_printf_message_fmt db 'The answer is: %d', 0xA, 0
_fscanf_specifier db '%d, %d', 0

align 8
g_file_handle dq 0

c_invalid_area_bit = 0x80000000

align 4
struct GridEntry
    area_size dd ?
    pos_x dd ?
    pos_y dd ? 
    temp_man_dist dd ?
    marked_infinite dd ?
ends

c_max_grid_entries = 256

g_grid_entries rb c_max_grid_entries * sizeof.GridEntry
g_num_grid_entries dd 0

g_min_x dd 0
g_max_x dd 0

g_min_y dd 0
g_max_y dd 0

g_num_10k_points dd 0

macro _max dest, src 
{
    cmp dest, src
    jae @f
    mov dest, src
@@:
}

macro _min dest, src 
{
    cmp dest, src
    jbe @f
    mov dest, src
@@:
}

macro abs_32 x
{
    mov eax, x
    sar x, 31
    xor eax, x
    sub eax, x
}

macro abs_diff_32 x, y
{
    sub x, y
    abs_32 x
}

section '.text' code readable executable


man_dist: ; rcx = x0, rdx = y0, r8 = x1, r9 = y1
    abs_diff_32 ecx, r8d
    mov r8d, eax
    abs_diff_32 edx, r9d
    add eax, r8d
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

    mov [g_min_x], -1
    mov [g_min_y], -1

.read_next_entry:
    mov r10d, [g_num_grid_entries]
    mov eax, sizeof.GridEntry
    mul r10d
    lea r11, [g_grid_entries + eax]
    lea r8, [r11 + GridEntry.pos_x]
    lea r9, [r11 + GridEntry.pos_y]
    mov r14, r8
    mov r15, r9

    mov rcx, [g_file_handle]
    mov rdx, _fscanf_specifier
    call [fscanf]

    cmp eax, -1
    jz .finished_read_entries
    mov r8d, dword [r14]
    mov r9d, dword [r15]
    _min [g_min_x], r8d
    _max [g_max_x], r8d
    _min [g_min_y], r9d
    _max [g_max_y], r9d
    add [g_num_grid_entries], 1
    jmp .read_next_entry

.finished_read_entries:
    virtual at rbp  
        .x_idx dd ?
        .y_idx dd ?
        .10k_accumulator dd ?
    end virtual

    mov eax, [g_min_y]
    mov [.y_idx], eax

    mov r14d, [g_max_x]
    mov r15d, [g_max_y]

    add r14d, 1 ; r14d = x end
    add r15d, 1 ; r15d = y end

    .loop_y:
        mov eax, [g_min_x]
        mov [.x_idx], eax
        cmp [.y_idx], r15d
        jz .end

        .loop_x:
        cmp [.x_idx], r14d
        jz .loop_x_end 

        xor edi, edi ; loop counter
        mov [.10k_accumulator], 0

        .next_grid_entry_test:
            cmp edi, [g_num_grid_entries]
            jz .finish_scan_grid_entries
            mov rax, sizeof.GridEntry
            mul edi
            lea r10, [g_grid_entries + rax]
            mov r8d, dword [r10 + GridEntry.pos_x]
            mov r9d, dword [r10 + GridEntry.pos_y] 
            mov ecx, [.x_idx]
            mov edx, [.y_idx]
            call man_dist
            add [.10k_accumulator], eax
            add edi, 1
            jmp .next_grid_entry_test

        .finish_scan_grid_entries:
            cmp [.10k_accumulator], 10000
            jae @f
            add [g_num_10k_points], 1

        @@: add [.x_idx], 1
            jmp .loop_x
            
        .loop_x_end:
            add [.y_idx], 1
            jmp .loop_y   


.end:
    mov rcx, _printf_message_fmt
    mov edx, [g_num_10k_points]
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
        fscanf,'fscanf',\
        printf,'printf'\


    include 'api\kernel32.inc'
    include 'api\user32.inc'
