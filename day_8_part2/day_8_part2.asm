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
    total_children dd ?
    next_child_read_idx dd ?
    num_metadata_entries dd ?
    my_child_index_in_parent dd ?
    parent_stack_entry_ptr dq ?
    child_value_array_ptr dq ?
ends

c_stack_size = 1024
c_child_val_buff_size = 1000000

g_child_val_buff rd c_child_val_buff_size
g_child_val_buff_cur_alloc dd 0

; stack for depth first traversal
align 8
g_stack rb sizeof.StackEntry * c_stack_size
g_stack_pos dd 0

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
    mov dword [g_stack + StackEntry.total_children], r8d
    mov dword [g_stack + StackEntry.num_metadata_entries], r9d
    mov qword [g_stack + StackEntry.parent_stack_entry_ptr], 0
    mov qword [g_stack + StackEntry.child_value_array_ptr], g_child_val_buff
    mov [g_child_val_buff_cur_alloc], r8d

    mov [g_input_cursor], 2
    mov [g_stack_pos], 1

.stack_pop_next:
    mov eax, [g_stack_pos]
    test eax, eax
    jz .end
    sub eax, 1
    mov r14d, sizeof.StackEntry
    mul r14d

    mov r15d, dword [g_stack + eax + StackEntry.next_child_read_idx]
    cmp r15d, dword [g_stack + eax + StackEntry.total_children]

    jz .sum_children_from_metadata_indicies
    mov r9d, r15d ; r9d = the child we are about to push stack index in parent
    add r15d, 1
    add dword [g_stack + eax + StackEntry.next_child_read_idx], 1
    ; push a new child

    mov r11d, [g_input_cursor]
    mov r13d, [g_input_numbers + r11d * 4] ; num children
    mov r14d, [g_input_numbers + r11d * 4 + 4] ; metadata count
    add [g_input_cursor], 2

    test r13d, r13d ; has any children?
    jz .sum_metadata_no_children 

; has children, push this onto stack
    mov r15d, eax
    add r15, g_stack ; r15 = parent ptr

    add eax, sizeof.StackEntry
    add [g_stack_pos], 1
    lea r12, [g_stack + eax]
    mov dword [r12 + StackEntry.num_metadata_entries], r14d
    mov dword [r12 + StackEntry.total_children], r13d
    mov dword [r12 + StackEntry.next_child_read_idx], 0
    mov qword [r12 + StackEntry.parent_stack_entry_ptr], r15
    mov dword [r12 + StackEntry.my_child_index_in_parent], r9d
    
    mov ecx, dword [g_child_val_buff_cur_alloc]
    lea rcx, [g_child_val_buff + rcx * 4]
    mov qword [r12 + StackEntry.child_value_array_ptr], rcx
    add dword [g_child_val_buff_cur_alloc], r13d

    jmp .stack_pop_next

.sum_metadata_no_children: ; expects metadata count in r14d
    test r14d, r14d

    jz .stack_pop_next

    ; find memory location for this childs accumulator 
    mov r15d, eax
    add r15, g_stack ; r15 = parent ptr
    lea r13, [r9 * 4]
    add r13, qword [r15 + StackEntry.child_value_array_ptr]

    mov ecx, [g_input_cursor]
    lea rcx, [ecx * 4 + g_input_numbers]

    add [g_input_cursor], r14d

    .read_metadata_inner:
        mov r15d, dword [rcx]
        add dword [r13], r15d
        add rcx, 4
        sub r14d, 1
        jnz .read_metadata_inner

    jmp .stack_pop_next

.sum_children_from_metadata_indicies: ; 
    mov r14d, dword [g_stack + eax + StackEntry.num_metadata_entries] ; r14d = num metadata
    sub [g_stack_pos], 1

    test r14d, r14d

    jz .stack_pop_next

    lea r15, [eax + g_stack] 
    mov r13, qword [r15 + StackEntry.child_value_array_ptr] ; r13 = child value array
    mov r10d, dword [r15 + StackEntry.total_children] ; r10d = total children

    mov ecx, [g_input_cursor]
    lea rcx, [rcx * 4 + g_input_numbers]

    add [g_input_cursor], r14d
    xor edx, edx ; edx = accumulator

    .sum_child_values_inner:
        mov r15d, dword [rcx]
        ; skip if zero
        test r15d, r15d
        jz @f
        cmp r15d, r10d
        ja @f ; bounds check

        ; sub 1 so we are 0-indexed
        sub r15, 1
        lea r15, [r15 * 4 + r13]
        add edx, dword [r15]
        
@@:     add rcx, 4
        sub r14d, 1
        jnz .sum_child_values_inner


    ; finished sum, check if this node was root, else add to parents value array and pop next stack entry
    mov r14, qword [g_stack + eax + StackEntry.parent_stack_entry_ptr]
    test r14, r14
    jz .end ; if root, accum is in edx, so just jump to end and print

    mov r12, qword [r14 + StackEntry.child_value_array_ptr]
    mov r13d, dword [g_stack + eax + StackEntry.my_child_index_in_parent]
    mov dword [r12 + r13 * 4], edx
    jmp .stack_pop_next

.end:
    mov rcx, _printf_message_fmt
    ; previous jmp put result into edx.
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
