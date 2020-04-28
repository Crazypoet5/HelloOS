;初始化显存选择子

TI_GDT equ 0 

RPL0 equ 0 

SELECTOR_VIDEO equ (0x0004<<3) +000b

[bits 32] 

section .data

num2data_buffer dq 0

put_int_buffer    dq    0     ; 定义8字节缓冲区用于数字到字符的转换

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
        cmp bx,2000

        jnl .roll_screen 

        jmp cursor

    .is_BS_char:   

        shl bx,1

        sub bx,2

        mov dword [gs:bx],0x0720

        shr bx,1

        cmp bx,2000

        jnl .roll_screen

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
        cmp bx,2000

        jnl .roll_screen   

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

;--------------------   将小端字节序的数字变成对应的ascii后，倒置   -----------------------

;输入：栈中参数为待打印的数字

;输出：在屏幕上打印16进制数字,并不会打印前缀0x,如打印10进制15时，只会直接打印f，不会是0xf

;------------------------------------------------------------------------------------------

global put_int16

put_int16:

   pushad

   mov ebp, esp

   mov eax, [ebp+4*9]		       ; call的返回地址占4字节+pushad的8个4字节

   mov edx, eax

   mov edi, 7                          ; 指定在put_int_buffer中初始的偏移量

   mov ecx, 8			       ; 32位数字中,16进制数字的位数是8个

   mov ebx, put_int_buffer



;将32位数字按照16进制的形式从低位到高位逐个处理,共处理8个16进制数字

.16based_4bits:			       ; 每4位二进制是16进制数字的1位,遍历每一位16进制数字

   and edx, 0x0000000F		       ; 解析16进制数字的每一位。and与操作后,edx只有低4位有效

   cmp edx, 9			       ; 数字0～9和a~f需要分别处理成对应的字符

   jg .is_A2F 

   add edx, '0'			       ; ascii码是8位大小。add求和操作后,edx低8位有效。

   jmp .store

.is_A2F:

   sub edx, 10			       ; A~F 减去10 所得到的差,再加上字符A的ascii码,便是A~F对应的ascii码

   add edx, 'A'



;将每一位数字转换成对应的字符后,按照类似“大端”的顺序存储到缓冲区put_int_buffer

;高位字符放在低地址,低位字符要放在高地址,这样和大端字节序类似,只不过咱们这里是字符序.

.store:

; 此时dl中应该是数字对应的字符的ascii码

   mov [ebx+edi], dl		       

   dec edi

   shr eax, 4

   mov edx, eax 

   loop .16based_4bits



;现在put_int_buffer中已全是字符,打印之前,

;把高位连续的字符去掉,比如把字符000123变成123

.ready_to_print:

   inc edi			       ; 此时edi退减为-1(0xffffffff),加1使其为0

.skip_prefix_0:  

   cmp edi,8			       ; 若已经比较第9个字符了，表示待打印的字符串为全0 

   je .full0 

;找出连续的0字符, edi做为非0的最高位字符的偏移

.go_on_skip:   

   mov cl, [put_int_buffer+edi]

   inc edi

   cmp cl, '0' 

   je .skip_prefix_0		       ; 继续判断下一位字符是否为字符0(不是数字0)

   dec edi			       ;edi在上面的inc操作中指向了下一个字符,若当前字符不为'0',要恢复edi指向当前字符		       

   jmp .put_each_num



.full0:

   mov cl,'0'			       ; 输入的数字为全0时，则只打印0

.put_each_num:

   push ecx			       ; 此时cl中为可打印的字符

   call put_char

   add esp, 4

   inc edi			       ; 使edi指向下一个字符

   mov cl, [put_int_buffer+edi]	       ; 获取下一个字符到cl寄存器

   cmp edi,8

   jl .put_each_num

   popad

   ret



global set_cursor

set_cursor:

   pushad

   mov bx, [esp+36]

;;;;;;; 1 先设置高8位 ;;;;;;;;

   mov dx, 0x03d4			  ;索引寄存器

   mov al, 0x0e				  ;用于提供光标位置的高8位

   out dx, al

   mov dx, 0x03d5			  ;通过读写数据端口0x3d5来获得或设置光标位置 

   mov al, bh

   out dx, al



;;;;;;; 2 再设置低8位 ;;;;;;;;;

   mov dx, 0x03d4

   mov al, 0x0f

   out dx, al

   mov dx, 0x03d5 

   mov al, bl

   out dx, al

   popad

   ret

        