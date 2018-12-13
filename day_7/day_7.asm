format PE64 console
entry start

include 'win64a.inc'

section '.data' data readable writeable

_filename db 'day_7_input.txt', 0
_fopen_mode db 'r', 0

_printf_message_fmt db 'The order is: %s', 0xA, 0
_fscanf_specifier db 'Step %c must be finished before step %c can begin. ', 0

struct DagNode
    edges rb 26
    num_edges db ?
    dep_count db ?
    is_valid db ?
ends

align 8
g_file_handle dq 0

c_num_nodes = 26

align 8
g_nodes rb sizeof.DagNode * c_num_nodes

align 8
g_exec_buffer rb c_num_nodes

align 4
g_num_exec_nodes dd ?

g_output_string rb c_num_nodes + 1 ; + 1 for null term
g_cur_out_char_idx dd 0

c_fgets_buff_size = 512
g_fgets_buff rb c_fgets_buff_size

section '.text' code readable executable

insertion_sort_u8_greater: ; rcx = pointer, rdx = num
    xor rax, rax

.outer:
    add rax, 1
    cmp rdx, rax 
    jbe .finish
    mov r8, rax

.inner:
    mov r9l, byte [rcx + r8]

    mov r10, r8
    sub r10, 1

    mov r11l, byte [rcx + r10]

    cmp r9l, r11l
    jl .outer

	; swap
    mov byte [rcx + r8], r11l
    mov byte [rcx + r10], r9l
	
    sub r8, 1
    test r8, r8
    jz .outer
    jmp .inner

.finish:
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

    mov rcx, g_nodes
    mov rdx, 0
    mov r8, sizeof.DagNode * c_num_nodes
    call [memset]

.read_next_entry:
    virtual at rbp
        .dependency db ?
        .node_id db ?
    end virtual

    mov rcx, g_fgets_buff
    mov rdx, c_fgets_buff_size
    mov r8, [g_file_handle]
    call [fgets]
    test rax, rax
    jz @f

    mov rcx, g_fgets_buff
    mov rdx, _fscanf_specifier
    lea r8, [.dependency]
    lea r9, [.node_id]
    call [sscanf]

    movzx r8, byte [.dependency]
    movzx r9, byte [.node_id]
    sub r8, 'A'
    sub r9, 'A'

    mov eax, sizeof.DagNode
    mul r8d
    lea r10, [g_nodes + rax]
    movzx r12, byte [r10 + DagNode.num_edges]
    mov byte [r10 + DagNode.edges + r12], r9l
    add byte [r10 + DagNode.num_edges], 1 ; add the dependant
    mov byte [r10 + DagNode.is_valid], 1
    
    mov eax, sizeof.DagNode
    mul r9l
    add byte [g_nodes + rax + DagNode.dep_count], 1 ; increment dependancy count
    mov byte [g_nodes + rax + DagNode.is_valid], 1
    jmp .read_next_entry
@@:

; find the starting nodes
    lea rdx, [g_nodes + c_num_nodes * sizeof.DagNode] ; rdx = end
    mov rax, g_nodes ; rax = cur node
    xor r9, r9 ; local num exec nodes
    xor r13, r13 ; cur node idx

.find_top_nodes_loop:
    cmp [rax + DagNode.is_valid], 0
    jz @f

    cmp [rax + DagNode.dep_count], 0
    jnz @f
    mov byte [g_exec_buffer + r9], r13l
    add r9, 1

@@: add rax, sizeof.DagNode
    add r13, 1
    cmp rax, rdx
    jnz .find_top_nodes_loop 

    mov [g_num_exec_nodes], r9d

.exec_graph_loop:
    mov rcx, g_exec_buffer
    mov edx, [g_num_exec_nodes]
    call insertion_sort_u8_greater

    ; pop top entry
    mov eax, [g_num_exec_nodes]
    test eax, eax
    jz .end

    ; pop next node idx    
    sub eax, 1
    movzx r8, [g_exec_buffer + eax] ; r8l = node idx
    sub [g_num_exec_nodes], 1

    ; push node to output string
    mov r14l, r8l
    add r14l, 'A'
    mov r15d, [g_cur_out_char_idx]
    mov [g_output_string + r15d], r14l
    add [g_cur_out_char_idx], 1

    ; decrement dependants 
    mov eax, sizeof.DagNode
    mul r8d
    lea r9, [g_nodes + eax]
    movzx r10, byte [r9 + DagNode.num_edges] ; r10 = num edges
    lea r11, [r9 + DagNode.edges] ; r11 = edge ptr
    mov r12, r11
    add r12, r10 ; r12 = end ptr

.test_edges_loop:
    cmp r11, r12
    jz .exec_graph_loop
    movzx r15, byte [r11] 
    mov eax, sizeof.DagNode
    mul r15d
    sub [g_nodes + eax + DagNode.dep_count], 1
    jnz .no_push_node
    mov eax, [g_num_exec_nodes]
    mov [g_exec_buffer + eax], r15l
    add [g_num_exec_nodes], 1

.no_push_node:
    add r11, 1
    jmp .test_edges_loop

.end:
    mov rcx, _printf_message_fmt
    mov edx, g_output_string
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
        memset,'memset',\
        fgets,'fgets'\


    include 'api\kernel32.inc'
    include 'api\user32.inc'
