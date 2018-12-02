format PE64 console
entry start

include 'win64a.inc'

c_max_lines = 1024
c_max_line_len = 128

section '.data' data readable writeable

_filename db 'day_2_input.txt', 0
_fopen_mode db 'r', 0
_printf_message_fmt db 'The two strings are %s and %s', 0xA, 0


align 8
g_file_handle dq 0
g_strings rd c_max_lines * c_max_line_len

section '.text' code readable executable

start:
    virtual at rbp + 8
        total_lines dq ?
    end virtual

    mov rbp, rsp
    sub rsp, 8 + 32
    mov rcx, _filename
    mov rdx, _fopen_mode
    call [fopen]

    test rax, rax
    jz .ret_main
    mov [g_file_handle], rax

    mov rbx, g_strings ; current string dest
    mov [total_lines], 0

.read_next_line:
    mov rcx, rbx
    mov rdx, c_max_line_len
    mov r8, [g_file_handle]
    call [fgets]
    test rax, rax ; EOF is nullptr (fgets returns char*)
    je .finish_read_lines
    add [total_lines], 1
    add rbx, c_max_line_len 
    jmp .read_next_line

.finish_read_lines:
    mov rax, [total_lines]
    test rax, rax
    jz .end
    
    mov rbx, c_max_line_len 
    mul rbx ; rax = all strings size
    lea r10, [g_strings + rax] ; r10 = string end ptr

    ; n^2 loop over all strings
    mov rbx, g_strings ; rbx = outer string

.search_outer_loop_begin:
    mov rdx, g_strings ; rdx = inner string

.search_inner_loop_begin:
    cmp rbx, rdx
    jz .search_inner_loop_end

    ; check for a match
    mov rax, 0 ; rax = loop counter
    mov r11, 0 ; r11 = difference check
.string_match_loop:
    ; all strings in input have same length.
    mov r14b, [rbx + rax]
    mov r15b, [rdx + rax]
    add rax, 1
    test r14b, r14b
    jz .string_match_end
    cmp r14b, r15b
    jz .string_match_loop
    add r11, 1
    jmp .string_match_loop


.string_match_end:
    cmp r11, 1
    jz .end ; found our string, in rbx and rdx

.search_inner_loop_end:
    add rdx, c_max_line_len ; increment inner string
    cmp rdx, r10
    jnz .search_inner_loop_begin

.search_outer_loop_end:
    add rbx, c_max_line_len ; increment outer string
    cmp rbx, r10
    jnz .search_outer_loop_begin
    ; should have found string by now, bad data?
    ud2


.end:
    mov rcx, _printf_message_fmt
    ; rdx already has a string
    mov r8, rbx

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
