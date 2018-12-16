format PE64 console
entry start

include 'win64a.inc'

section '.data' data readable writeable

_filename db 'day_8_input.txt', 0
_fopen_mode db 'r', 0

_printf_message_fmt db 'The answer is %d', 0xA, 0
_fscanf_specifier db '%d', 0


align 8
g_file_handle dq 0

c_input_buff_size = 50000

g_input_numbers rd c_input_buff_size
g_input_size dd 0

g_input_cursor dd 0

struct StackEntry
    children_left dd ?
    metadata_entries dd ?
ends

c_stack_size = 1024

; stack for depth first traversal
g_stack rb sizeof.StackEntry * c_stack_size
g_stack_pos dd 0

g_metadata_count dd 0

section '.text' code readable executable

start:
.c_stack_size = 32 + 8
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

.read_next_input:
    mov rcx, [g_file_handle]
    mov rdx, _fscanf_specifier
    mov r8d, [g_input_size]
    lea r8d, [g_input_numbers + r8 * 4]
    call [fscanf]
    cmp eax, -1
    je .finished_read_input
    add [g_input_size], 1
    jmp .read_next_input


.finished_read_input:
    mov r8d, [g_input_numbers]
    mov r9d, [g_input_numbers + 4]
    mov dword [g_stack + StackEntry.children_left], r8d
    mov dword [g_stack + StackEntry.metadata_entries], r9d
    mov [g_input_cursor], 2
    mov [g_stack_pos], 1

.stack_pop_next:
    mov r9d, [g_stack_pos]
    test r9d, r9d
    jz .end
    sub r9d, 1

    sub dword [g_stack + sizeof.StackEntry * r9d + StackEntry.children_left], 1
    jb .read_metadata_from_stack
    ; push a new child

    mov r11d, [g_input_cursor]
    mov r13d, [g_input_numbers + r11d * 4] ; num children
    mov r14d, [g_input_numbers + r11d * 4 + 4] ; metadata count
    add [g_input_cursor], 2

    test r13d, r13d ; has any children?
    jz .read_metadata_inline 

; has children, push this onto stack
    add r9d, 1
    add [g_stack_pos], 1
    lea r12, [g_stack + sizeof.StackEntry * r9d]
    mov dword [r12 + StackEntry.metadata_entries], r14d
    mov dword [r12 + StackEntry.children_left], r13d
    jmp .stack_pop_next

.read_metadata_from_stack: ; r9d has current stack pos
    mov r14d, dword [g_stack + sizeof.StackEntry * r9d + StackEntry.metadata_entries] ; r14d = num metadata
    sub [g_stack_pos], 1

.read_metadata_inline: ; expects metadata count in r14d
    test r14d, r14d
    jz .stack_pop_next
    mov ecx, [g_input_cursor]
    shl ecx, 2
    add rcx, g_input_numbers ; rcx = input pointer

    add [g_input_cursor], r14d

    .read_metadata_inner:
        mov r15d, dword [rcx]
        add [g_metadata_count], r15d
        add rcx, 4
        sub r14d, 1
        jnz .read_metadata_inner

    jmp .stack_pop_next


.end:
    mov rcx, _printf_message_fmt
    mov edx, [g_metadata_count]
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
        printf,'printf',\
        memset,'memset',\
        fgets,'fgets',\
        puts, 'puts'\


    include 'api\kernel32.inc'
    include 'api\user32.inc'
