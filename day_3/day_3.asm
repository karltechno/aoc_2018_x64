format PE64 console
entry start

include 'win64a.inc'

section '.data' data readable writeable

_filename db 'day_3_input.txt', 0
_fopen_mode db 'r', 0
_fscanf_read_specifier db '#%d @ %d,%d: %dx%d', 0
_printf_message_fmt db 'The answer is: %d', 0xA, 0

c_fgets_buff_sz = 256
g_fgets_buff rb c_fgets_buff_sz

align 8
g_file_handle dq 0

c_grid_dim = 1024
c_grid_dim_log2 = 10

g_grid rb c_grid_dim * c_grid_dim

align 4
g_claim_id dd 0
g_claim_left_pad dd 0
g_claim_top_pad dd 0
g_claim_width dd 0
g_claim_height dd 0

g_numTilesWithOverlap dd 0

section '.text' code readable executable

start:
.c_stack_size = 32 + 8 * 4 ; fscanf takes 7 args here, 3 spill to stack + 1 to align

    push rbp
    sub rsp, .c_stack_size
    mov rbp, rsp
    add rbp, 32

    mov rcx, _filename
    mov rdx, _fopen_mode
    call [fopen]

    test rax, rax
    jz .ret_main
    mov [g_file_handle], rax

.process_next_claim:
    mov rcx, g_fgets_buff 
    mov rdx, c_fgets_buff_sz
    mov r8, [g_file_handle]
    call [fgets]
    test rax, rax
    jz .end
    
    mov rcx, g_fgets_buff
    mov rdx, _fscanf_read_specifier
    mov r8, g_claim_id
    mov r9, g_claim_left_pad

    mov rax, rbp
    mov qword [rax], g_claim_top_pad
    add rax, 8
    mov qword [rax], g_claim_width
    add rax, 8
    mov qword [rax], g_claim_height
    call [sscanf]

    ; loop over each row
    mov ecx, [g_claim_top_pad] 
    shl ecx, c_grid_dim_log2
    add ecx, [g_claim_left_pad]
    lea rax, [g_grid + rcx] ; rax = current grid row begin
    mov rcx, rax ; rcx = current grid ptr
    mov r9d, [g_claim_height] ; r9 = row counter
    mov r8d, [g_claim_width]; r8 = column counter
.row_loop_inner:
    cmp byte [rcx], 1
    jne .no_increment_overlap ; only increment if exactly 1, always add 1 to grid position if wont overflow
    add [g_numTilesWithOverlap], 1
.no_increment_overlap:
    cmp byte [rcx], 255
    je .no_add_to_grid ; avoid overflow
    add byte [rcx], 1
.no_add_to_grid:
    add rcx, 1
    sub r8, 1
    jnz .row_loop_inner
    ; finished row
    sub r9, 1
    mov r8d, [g_claim_width]
    jz .process_next_claim
    add rax, c_grid_dim
    mov rcx, rax
    jmp .row_loop_inner

.end:
    mov rcx, _printf_message_fmt
    mov edx, [g_numTilesWithOverlap]
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
        fgets,'fgets'\

    include 'api\kernel32.inc'
    include 'api\user32.inc'
