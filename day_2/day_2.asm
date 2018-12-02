format PE64 console
entry start

include 'win64a.inc'

c_sizeof_read_buffer = 1024
c_num_char_array_size = 26

section '.data' data readable writeable

_filename db 'day_2_input.txt', 0
_fopen_mode db 'r', 0
_printf_message_fmt db 'The checksum is: %d', 0xA, 0


align 8
g_file_handle dq 0
g_num_char_array rd c_num_char_array_size
g_read_buffer rb c_sizeof_read_buffer

section '.text' code readable executable

start:
    virtual at rbp + 8
        exactly_two dq ?
        exactly_three dq ?
    end virtual

    mov rbp, rsp
    sub rsp, 8 + 32
    mov rcx, _filename
    mov rdx, _fopen_mode
    call [fopen]

    test rax, rax
    jz .ret_main
    mov [g_file_handle], rax

    mov [exactly_two], 0
    mov [exactly_three], 0

.read_next_line:
    mov rcx, g_read_buffer
    mov rdx, c_sizeof_read_buffer
    mov r8, [g_file_handle]
    call [fgets]
    test rax, rax ; EOF is nullptr (fgets returns char*)
    je .end

    mov rcx, g_num_char_array
    mov rdx, 0
    mov r8, c_num_char_array_size * 4
    call [memset] 

    mov rax, 0 ; g_read_buffer index

.eval_next_char:
    mov dl, [g_read_buffer + rax]
    test dl, dl
    jz .eval_counters_begin
    sub dl, 97 ; ascii 'a'
    add [g_num_char_array + edx * 4], 1 ; increment char counter
    add rax, 1
    jmp .eval_next_char

.eval_counters_begin:
    mov eax, 0
    mov r8, 0 ; has two (0 or 1)
    mov r9, 0 ; has three (0 or 1)
    mov r10, 1 ; store one for cmov

.eval_counter_loop_start:
    mov edx, [g_num_char_array + eax * 4]
    cmp edx, 3 ; compare 3
    cmovz r9, r10

    cmp edx, 2 ; compare 2
    cmovz r8, r10

    add eax, 1
    cmp eax, c_num_char_array_size
    je .eval_counter_end
    test r8, r9
    jz .eval_counter_loop_start

.eval_counter_end:
    add [exactly_two], r8
    add [exactly_three], r9
    jmp .read_next_line

.end:
    mov rcx, _printf_message_fmt

    mov rax, [exactly_two] ; compute exactly_two * exactly_three (the hash)
    mul [exactly_three]
    mov rdx, rax

    call [printf] 

    mov rcx, [g_file_handle]
    test rcx, rcx
    jz .ret_main
    call [fclose]

.ret_main:
    add rsp, 8 + 32
    xor eax, eax
    ret


section '.idata' import data readable writeable

    library kernel32,'KERNEL32.DLL',\
	    user32,'USER32.DLL',\
        msvcrt,'MSVCRT.dll'

    import msvcrt,\
        fopen,'fopen',\
        fclose,'fclose',\
        fgets,'fgets',\
        printf,'printf',\
        memset,'memset'\

    include 'api\kernel32.inc'
    include 'api\user32.inc'
