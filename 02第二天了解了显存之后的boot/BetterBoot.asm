  ;不再依靠中断显示字符直接依靠利用显存的0xb800处的  文本模式内存
      
       org    7c00h                   ; 告诉编译器程序加载到0000:7C00处


        mov ax, cx

        mov ds, ax

        mov es, ax

        call  DispStr           ; 调用显示字符串例程

        ;jmp   $                 ; 无限循环

DispStr: 
      ;先清屏，然后再输出字符
        mov ah, 06h             ;设置中断的功能号，上卷
	mov al, 0h             
 ;设置上卷的行数，这里设为0，则代表上卷全部行，也就是清屏      
	mov cx,0 
	mov dx,184fh
        int 10h                 ;执行10号中断
	mov ax,0b800h       
	mov gs,ax
        mov byte [gs:0000h],"H"
	mov byte [gs:0001h],0xA4
        mov byte [gs:0002h],"E"
        mov byte [gs:0003h],0xA4
	mov byte [gs:0004h],"L"
        mov byte [gs:0005h],0xA4
	mov byte [gs:0006h],"L"
        mov byte [gs:0007h],0xA4
	mov byte [gs:0008h],"O"
        mov byte [gs:0009h],0xA4
        ret 

times  510-($-$$)  db   0      ; 填充剩余空间，使生成的二进制代码恰好为512字节

dw     0aa55h                   ; 结束标志,注意一下不能用字母开头

