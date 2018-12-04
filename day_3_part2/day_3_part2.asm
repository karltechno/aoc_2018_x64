format PE64 console
entry start

include 'win64a.inc'

section '.data' data readable writeable

_filename db 'day_3_input.txt', 0
_fopen_mode db 'r', 0
_fscanf_read_specifier db '#%d @ %d,%d: %dx%d', 0
_printf_message_fmt db 'The free claim id is: %d', 0xA, 0

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

section '.text' code readable executable

read_next_claim:
.c_stack_size = 32 + 8 * 4
    push rbp
    sub rsp, .c_stack_size
    mov rbp, rsp
    add rbp, 32

    mov rcx, g_fgets_buff 
    mov rdx, c_fgets_buff_sz
    mov r8, [g_file_handle]
    call [fgets]
    test rax, rax
    jz @f
    
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

@@: add rsp, .c_stack_size
    pop rbp
    ret

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

.build_grid_next_claim:
    call read_next_claim
    test rax, rax
    jz .find_clear_claim_start

    ; loop over each row
    mov ecx, [g_claim_top_pad] 
    shl ecx, c_grid_dim_log2
    add ecx, [g_claim_left_pad]
    lea rax, [g_grid + rcx] ; rax = current grid row begin
    mov rcx, rax ; rcx = current grid ptr
    mov r9d, [g_claim_height] ; r9 = row counter
    mov r8d, [g_claim_width]; r8 = column counter

.build_grid_row_loop:
    cmp byte [rcx], -1
    jz @f
    add byte [rcx], 1
@@: add rcx, 1
    sub r8, 1
    jnz .build_grid_row_loop
    ; finished row
    sub r9, 1
    mov r8d, [g_claim_width]
    jz .build_grid_next_claim
    add rax, c_grid_dim
    mov rcx, rax
    jmp .build_grid_row_loop

.find_clear_claim_start:
    ; seek to start
    mov rcx, [g_file_handle]
    xor rdx, rdx
    xor r8, r8 ; SEEK_SET
    call [fseek]

    
.find_clear_claim_try_next:
    call read_next_claim
    test rax, rax
    jnz @f
    ud2 ; should not reach with good data
@@:
    ; loop over each row
    mov ecx, [g_claim_top_pad] 
    shl ecx, c_grid_dim_log2
    add ecx, [g_claim_left_pad]
    lea rax, [g_grid + rcx] ; rax = current grid row begin
    mov rcx, rax ; rcx = current grid ptr
    mov r9d, [g_claim_height] ; r9 = row counter
    mov r8d, [g_claim_width]; r8 = column counter

.find_clear_claim_loop:
    cmp byte [rcx], 1
    jnz .find_clear_claim_try_next
    add rcx, 1
    sub r8, 1
    jnz .find_clear_claim_loop
    ; finished row
    sub r9, 1
    jz .end ; everything was free!
    mov r8d, [g_claim_width]
    add rax, c_grid_dim
    mov rcx, rax
    jmp .find_clear_claim_loop

.end:
    mov rcx, _printf_message_fmt
    mov edx, [g_claim_id]
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
        fgets,'fgets',\
        fseek,'fseek'\

    include 'api\kernel32.inc'
    include 'api\user32.inc'
