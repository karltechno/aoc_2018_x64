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
g_freqHistory rd 1024 * 1024

g_inputList rd 2048

section '.text' code readable executable

start:
    push rbp
    mov rbp, rsp

    virtual at rbp + 16
        num_input dq ?
    end virtual

    sub rsp, 20h
    mov rcx, _filename
    mov rdx, _fopen_mode
    call [fopen]

    test rax, rax
    jz .ret_main
    mov [g_file_handle], rax

.read_next:
    mov rcx, [g_file_handle]
    mov rdx, _fscanf_read_specifier
    mov rax, [num_input]
    lea r8, [g_inputList + 4 * rax] 
    call [fscanf]
    cmp eax, 0xFFFFFFFF ; EOF
    je .search_loop_setup
    add [num_input], 1
    jmp .read_next


.search_loop_setup:
    mov [g_freqHistory], 0 ; first history = 0 
    mov r8d, 1 ; r8 = num entries in freq history

    mov r10d, [g_inputList] ; r10 = current freq (starts at first input)
    xor rdx, rdx ; rdx = current inputList index

; super dumb n^2 loop
.search_loop_begin:
    mov r9, 0 ; r9 = freq history loop counter
.search_loop_inner:
    cmp r10d, [g_freqHistory + r9d * 4]
    jz .success
    add r9, 1
    cmp r9, r8 ; freq loop end check
    jnz .search_loop_inner
.search_loop_end:
    ; first wrap around input list index
    add rdx, 1
    cmp rdx, [num_input]
    jnz .search_loop_no_wrap
    xor rdx, rdx ; set to 0 to wrap
    
.search_loop_no_wrap:
    mov [g_freqHistory + 4 * r8d], r10d ; put old frequency in list
    add r8d, 1 ; increment freq list size
    add r10d, [g_inputList + edx * 4] ; update current frequency
    jmp .search_loop_begin

.success:
    mov rcx, _printf_message_fmt
    mov rdx, r10
    call [printf] 

    mov rcx, [g_file_handle]
    test rcx, rcx
    jz .ret_main
    sub rsp, 20h
    call [fclose]
    add rsp, 20h

.ret_main:
    add rsp, 20h
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
