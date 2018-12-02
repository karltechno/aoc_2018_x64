format PE64 console
entry start

include 'win64a.inc'

section '.data' data readable writeable

_filename db 'day_1_input.txt', 0
_fopen_mode db 'r', 0
_fscanf_read_specifier db '%d', 0
_printf_message_fmt db 'The answer is: %d', 0xA, 0

align 8
g_file_handle dq 0

section '.text' code readable executable

start:
    virtual at rbp + 8
        freq_update dq ?
    end virtual

    mov rbp, rsp
    sub rsp, 48h
    mov rcx, _filename
    mov rdx, _fopen_mode
    call [fopen]

    test rax, rax
    jz .ret_main
    mov [g_file_handle], rax

    mov rdi, 0 ; accumulator

.read_next:
    mov [freq_update], 0 ; reset counter
    mov rcx, [g_file_handle]
    mov rdx, _fscanf_read_specifier
    lea r8, [freq_update] 
    call [fscanf]
    add rdi, [freq_update]
    cmp eax, 0xFFFFFFFF ; EOF
    jne .read_next

.end:
    mov rcx, _printf_message_fmt
    mov rdx, rdi
    call [printf] 

    mov rcx, [g_file_handle]
    test rcx, rcx
    jz .ret_main
    call [fclose]

.ret_main:
    add rsp, 48h
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
