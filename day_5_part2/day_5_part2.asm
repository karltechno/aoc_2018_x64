format PE64 console
entry start

include 'win64a.inc'

section '.data' data readable writeable

_filename db 'day_5_input.txt', 0
_fopen_mode db 'r', 0

_printf_message_fmt db 'The answer is: %d', 0xA, 0

struct TextStream
    stream_data dq ?
    stream_size dq ?
ends

struct CompactAlphaData
    current_char_compact_idx dd ?
    compacted_char_size_array rd 26
ends

align 8
g_file_handle dq 0

align 8
g_original_stream TextStream
g_stream1 TextStream
g_stream2 TextStream

align 4
g_compact_alpha_data CompactAlphaData

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

    sub rsp, .c_stack_size
    mov rbp, rsp
    add rbp, 32

    mov rcx, _filename
    mov rdx, _fopen_mode
    call [fopen]

    test rax, rax
    jz .ret_main
    mov [g_file_handle], rax

    mov rcx, rax
    mov rdx, 0
    mov r8, 2; SEEK_END
    call [fseek]
    
    mov rcx, [g_file_handle]
    call [ftell]
    mov [g_original_stream.stream_size], rax
    add rax, 1 ; null term at end of each buffer (so we don't need to special case the last char)
    mov rcx, 3
    mul rcx ; *3 (3 buffers in part2)
    mov rcx, rax
    call [malloc]
    mov r9, [g_original_stream.stream_size]
    mov r8, r9 ; r8 = size
    add r9, 1 ; r9 = size + 1
    

    mov [g_original_stream.stream_data], rax
    mov byte [rax + r8], 0
    add rax, r9

    mov [g_stream1.stream_data], rax
    mov byte [rax + r8], 0
    add rax, r9

    mov [g_stream2.stream_data], rax
    mov byte [rax + r8], 0

    mov rcx, [g_file_handle]
    mov rdx, 0
    mov r8, 0; SEEK_SET
    call [fseek]
    
    mov rcx, [g_original_stream.stream_data]
    mov rdx, [g_original_stream.stream_size]
    mov r8, 1
    mov r9, [g_file_handle]
    call [fread]
    test rax, rax
    jnz .compact_next_alpha
    ud2

.compact_next_alpha:
    mov [g_stream2.stream_size], 0
    mov [g_stream1.stream_size], 0

    mov ecx, [g_compact_alpha_data.current_char_compact_idx]
    add ecx, 'a' ; ecx = the char
    mov rax, [g_original_stream.stream_data] ; rax = original stream ptr
    mov r8, [g_stream1.stream_data] ; r8 = dest stream ptr
    mov r9, rax
    add r9, [g_original_stream.stream_size] ; r9 = original stream end ptr
    ; compact original stream into stream 1, removing char in cl (upper or lower)
@@: cmp rax, r9
    jz .compact_loop_start
    mov r10l, byte [rax]
    add rax, 1
    mov r11l, r10l ; r11 = r10 copy
    or r10, 20h
    cmp r10l, cl
    jz @r ; remove this char
    mov byte [r8], r11l
    add r8, 1
    add [g_stream1.stream_size], 1
    jmp @r

    mov rcx, [g_stream1.stream_size]
    mov byte [g_stream1.stream_data + rcx], 0

.compact_loop_start:
    xor rax, rax ; rax = num bytes compacted
    mov rdx, [g_stream1.stream_size] ; 
    add rdx, [g_stream1.stream_data]
    mov rcx, [g_stream1.stream_data] ; rcx = stream ptr
    mov r15, [g_stream2.stream_data] ; r15 = stream2 out ptr

    .compact_loop_inner:
        mov r8l, byte [rcx]
        mov r9l, byte [rcx + 1]
        add rcx, 1
        xor r9l, r8l 
        cmp r9l, 20h ; if chars are lower and upper then xor will leave only uppercase bit.
        jz .compact_two
        ; nothing to compact, add byte to other stream.
        mov byte [r15], r8l
        add [g_stream2.stream_size], 1
        add r15, 1
        jmp .compact_loop_end_check

    .compact_two:
        add rax, 2
        add rcx, 1

    .compact_loop_end_check: 
        cmp rdx, rcx
        ja .compact_loop_inner

    .compact_loop_end:
        test rax, rax
        jz .compact_finish
        
        ; swap buffers
        mov r10, [g_stream1.stream_data]
        mov r15, [g_stream2.stream_data]
        mov [g_stream2.stream_data], r10
        mov [g_stream1.stream_data], r15
        mov r12, [g_stream2.stream_size]
        mov [g_stream1.stream_size], r12
        mov [g_stream2.stream_size], 0
        mov byte [r15 + r12], 0
        jmp .compact_loop_start

    .compact_finish:
        mov r15d, [g_compact_alpha_data.current_char_compact_idx]
        mov r14, [g_stream1.stream_size]
        mov [g_compact_alpha_data.compacted_char_size_array + r15d * 4], r14d
        add [g_compact_alpha_data.current_char_compact_idx], 1
        cmp [g_compact_alpha_data.current_char_compact_idx], 26
        jz .find_shortest_compaction
        jmp .compact_next_alpha

.find_shortest_compaction: 
    mov eax, 0xffffffff
    xor rcx, rcx ; idx

@@: cmp rcx, 26
    jz .end
    mov r14d, [g_compact_alpha_data.compacted_char_size_array + rcx * 4]
    add rcx, 1
    cmp eax, r14d
    cmova eax, r14d
    jmp @r

.end:
    mov rcx, _printf_message_fmt
    mov edx, eax
    call [printf] 

    mov rcx, [g_file_handle]
    test rcx, rcx
    jz .ret_main
    call [fclose]

    mov rcx, [g_original_stream.stream_data]
    call [free]

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
        fread,'fread',\
        printf,'printf',\
        ftell,'ftell',\
        fseek,'fseek',\
        malloc,'malloc',\
        free,'free'\


    include 'api\kernel32.inc'
    include 'api\user32.inc'
