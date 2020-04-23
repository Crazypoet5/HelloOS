;初始化显存选择子
TI_GDT equ 0 
RPL0 equ 0 
SELECTOR_VIDEO equ (0x0004<<3) +000b
[bits 32] 
section .data
num2data_buffer dq 0
section .text 
global put_str
put_str:
    push ebp
    push ecx
    mov ecx,0
    mov ebp,[esp+12]
    string:
        mov cl,[ebp]
        cmp cl,0
        jz  str_over
        push ecx
        call put_char
        inc ebp
        add esp,4 
    loop string
str_over:
    pop ecx
    pop ebp
    ret 
;------------------------ put_char -----------------------------功能描述把栈中的字符写入光标所在处;－－－－－－－－－－『－－－－一－－－－－－－－ ------- ----------- - -- -- - -------’- 
global put_char 
put_char: 
    pushad ;备份 32 位寄存器环境,为了不将之前用的的寄存器中的值覆盖，
;因此选择将所有32位的寄存器全部保存到栈中
;需要保证 gs 中为正确的视频段选择为保险起见， 每次打印时都为 gs 赋值
    mov ax, SELECTOR_VIDEO ;不能直接把立即数送入段寄存器
    mov gs, ax 

; ; ; ; ; ; ; ; ; ; 获取当前光标位置; ; ; ; ; ; ; ; ;先获得高
    mov dx, 0x03d4 
    mov al, 0x0e 
    out dx, al 
    mov dx, 0x03d5 
    in  al, dx 
    mov ah, al 


;索引寄存器
;用于提供光析位置的高
;通过读写数据端口 0x d5 来获得或设置光标位置
;得到了光标位置的高
;再获取
    mov dx, 0x03d4 
    mov al, 0x0f 
    out dx, al 
    mov dx, 0x03d5 
    in  al, dx

    ;将光标值保存到bx中
    mov bx,ax
    mov al,[esp+36] ;因为利用函数调用的这个模块，因此参数在栈中，由于之前push了8个4字节的寄存器 
    ;因此偏移量是32+4

    ;判断字符是否是可显示的字符，例如回车，换行，等是不可显示的
    cmp al,0x0d ;如果是回车
    jz .is_enter_char
    cmp al,0x0a ;如果是换行
    jz .is_next_line_char
    cmp al, 0x08 ;退格符
    jz .is_BS_char
    jmp .put_other
    .put_other:
        shl bx,1  
        mov byte [gs:bx],al
        inc bx
        mov byte [gs:bx],0x07
        shr bx,1
        inc bx   
        jmp cursor
    .is_BS_char:   
        shl bx,1
        sub bx,2
        mov dword [gs:bx],0x0720
        shr bx,1
        cmp bx,2000
        jz .roll_screen
        jmp cursor
    .is_enter_char: 
        jmp .is_next_line_char
    .is_next_line_char:
        xor dx,dx
        mov ax,bx
        mov si,80
        div si
        sub bx,dx
        add bx,80    
        jmp cursor
    ;屏幕行范围是0~24,滚屏的原理是将屏幕的1~24行搬运到0~23行,再将第24行用空格填充
 .roll_screen:				  ; 若超出屏幕大小，开始滚屏
   cld  
   mov ecx, 960				  ; 一共有2000-80=1920个字符要搬运,共1920*2=3840字节.一次搬4字节,共3840/4=960次 
   mov esi, 0xc00b80a0			  ; 第1行行首
   mov edi, 0xc00b8000			  ; 第0行行首
   rep movsd				  

;;;;;;;将最后一行填充为空白
   mov ebx, 3840			  ; 最后一行首字符的第一个字节偏移= 1920 * 2
   mov ecx, 80				  ;一行是80字符(160字节),每次清理1字符(2字节),一行需要移动80次
 .cls:
   mov word [gs:ebx], 0x0720		  ;0x0720是黑底白字的空格键
   add ebx, 2
   loop .cls 
   mov bx,1920  
    cursor: 
 ;将光标设为 bx.
 ; ; ; ; ; ; ; 先设置高8位;
        mov dx, 0x03d4 ;索引寄存器
        mov al, 0x0e ;用于提供光标位置的高
        out dx, al 
        mov dx, 0x03d5 ;通过读写数据端口 Ox3出来获得或设置光标位置
        mov al, bh 
        out dx, al 
 
 ;;;;;;; 再设置低8位
        mov dx, 0x03d4 
        mov al, 0x0f 
        out dx, al 
        mov dx, 0x03d5 
        mov al, bl 
        out dx, al
    return:
        popad
        ret
global put_int
put_int:
   pushad 
   mov eax,[esp+4*9]
   mov ebx,eax 
   mov ebp,num2data_buffer
   mov esi,7
.num_to_char:
    xor edx,edx
    mov di,10
    div di
    add dl,'0'
    mov byte [ebp+esi],dl
    dec esi
    cmp ax,0
    jz start_print_num
    loop .num_to_char
start_print_num:
    inc esi
    mov eax,0
    mov al,[ebp+esi]
    push eax
    call put_char
    add esp,4
    cmp esi,7
    jz print_num_over
    loop start_print_num
print_num_over:
    popad
    ret

        