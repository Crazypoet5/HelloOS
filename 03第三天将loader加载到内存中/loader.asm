     %include "boot.inc"  
section loader vstart=LOADER_BASE_ADDR
        ; mov     ax, 0600h
        ; mov     bx, 0700h
        ; mov     cx, 0                   ; 左上角: (0, 0)
        ; mov     dx, 184fh
        ; int 10h
        mov byte [gs:00a0h],"L"
	mov byte [gs:00a1h],0xA4
        mov byte [gs:0002h],"O"
        mov byte [gs:0003h],0xA4
	mov byte [gs:0004h],"A"
        mov byte [gs:0005h],0xA4
	mov byte [gs:0006h],"D"
        mov byte [gs:0007h],0xA4
	mov byte [gs:0008h],"E"
        mov byte [gs:0009h],0xA4
 	mov byte [gs:000ah],"R"
        mov byte [gs:000bh],0xA4
        jmp $
