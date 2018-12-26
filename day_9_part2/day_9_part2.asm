format PE64 console
entry start

include 'win64a.inc'

section '.data' data readable writeable

_filename db 'day_9_input.txt', 0
_fopen_mode db 'r', 0

_printf_message_fmt db 'The answer is %u', 0xA, 0
_fscanf_specifier db '%d players; last marble is worth %d points', 0


align 8
g_file_handle dq 0

g_last_marble_val dd 0

c_max_players = 1024

c_marble_link_pool_size = 1024 * 10240

struct marble_node
    prev dq ?
    next dq ?
    val dd ?
    _pad_ dd ?
ends

align 8
g_marble_pool rb c_marble_link_pool_size * sizeof.marble_node
g_cur_marble_alloc_byte_offset dq 0
g_cur_marble_ptr dq 0

align 4
g_next_marble_val dd 0


g_player_scores rd c_max_players

g_next_player_idx dd 0
g_total_players dd 0

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

    mov rcx, [g_file_handle]
    mov rdx, _fscanf_specifier
    mov r8, g_total_players
    mov r9, g_last_marble_val
    call [fscanf]

    mov eax, 100
    mul [g_last_marble_val]
    mov [g_last_marble_val], eax

    cmp [g_total_players], c_max_players
    jna @f
    ud2 
@@:
   ; initial state
    mov rcx, g_marble_pool
    mov [g_cur_marble_alloc_byte_offset], sizeof.marble_node

    mov [rcx + marble_node.prev], rcx
    mov [rcx + marble_node.next], rcx
    mov [rcx + marble_node.val], 0

    mov [g_cur_marble_ptr], rcx
    mov [g_next_marble_val], 1
    

.work_loop:
    mov eax, [g_next_marble_val]
    mov r14d, eax ; r14d this marble value
    mov r11d, 23
    xor edx, edx
    div r11d

    test edx, edx ; mod 23 == 0?
    jz .do_mod_23

    ; allocate marble
    mov r9, [g_cur_marble_alloc_byte_offset]
    lea rsi, [g_marble_pool + r9] ; rsi = new marble
    mov dword [rsi + marble_node.val], r14d

    add [g_cur_marble_alloc_byte_offset], sizeof.marble_node

    mov rcx, [g_cur_marble_ptr]
    mov rcx, [rcx + marble_node.next] ; rcx = marble to the left
    mov rdx, [rcx + marble_node.next] ; rdx = marble to the right
    
    mov [rcx + marble_node.next], rsi
    mov [rdx + marble_node.prev], rsi

    mov [rsi + marble_node.next], rdx
    mov [rsi + marble_node.prev], rcx
    mov [g_cur_marble_ptr], rsi

.work_loop_test_end:
    mov r14d, [g_next_marble_val]
    add [g_next_marble_val], 1
    mov eax, [g_next_player_idx]
    add eax, 1
    xor edx, edx
    div [g_total_players]
    mov [g_next_player_idx], edx

    cmp r14d, [g_last_marble_val]
    jz .find_best_score
    jmp .work_loop

.do_mod_23:
    ; add the score
    mov eax, dword [g_next_player_idx]
    mov ecx, dword [g_next_marble_val]
    add [g_player_scores + eax * 4], ecx

    ; find marble 7 ccw from current
    mov r10, [g_cur_marble_ptr]
    mov r10, [r10 + marble_node.prev]
    mov r10, [r10 + marble_node.prev]
    mov r10, [r10 + marble_node.prev]
    mov r10, [r10 + marble_node.prev]
    mov r10, [r10 + marble_node.prev]
    mov r10, [r10 + marble_node.prev]
    mov r10, [r10 + marble_node.prev]

    mov r8d, [r10 + marble_node.val]
    add [g_player_scores + eax * 4], r8d ; add the score too
    mov r9, [r10 + marble_node.next] ; r9 = next node
    mov [g_cur_marble_ptr], r9
    
    mov r13, [r10 + marble_node.prev] ; r13 = prev node
    ; unlink 
    mov [r13 + marble_node.next], r9
    mov [r9 + marble_node.prev], r13
    
    jmp .work_loop_test_end

.find_best_score:
    mov ecx, [g_total_players]
    mov r8, g_player_scores
    xor edx, edx

@@: mov esi, [r8]
    cmp esi, edx
    cmova edx, esi
    add r8, 4
    sub ecx, 1
    jnz @r

.end:
    mov rcx, _printf_message_fmt
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
