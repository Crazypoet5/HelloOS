        org    7c00h                   ; 告诉编译器程序加载到0000:7C00处

        mov ax, cx

        mov ds, ax

        mov es, ax

        call  DispStr           ; 调用显示字符串例程

        jmp   $                 ; 无限循环

DispStr:

        mov   ax, BootMessage 

        mov   bp, ax           ; ES:BP= 字符串地址

        mov   cx, 16           ; CX= 字符串长度

        mov   ax, 1301H       ; AH= 13H, AL= 01H

        mov   bx, 000CH        ; 页号为0(BH= 0) 黑底红字(BL= 0CH，高亮)

        mov   dl, 0             

        int   10H              ; 调用BIOS的10号中断

        ret

BootMessage:
         db   "Hello, OS World!"  ; 要显示的字符串

times  510-($-$$)  db   0      ; 填充剩余空间，使生成的二进制代码恰好为512字节

dw     0aa55h                   ; 结束标志

