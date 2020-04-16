   ;初入保护模式
   
   %include "boot.inc"  
section loader vstart=LOADER_BASE_ADDR
        jmp loader_start
        ;GDT开始定义
        
        GDT_BASE dd 0x00000000
                 dd 0x00000000
        CODE_SEG dd 0x0000ffff
                 dd  00000000_1_1_0_0_1111_1_00_1_1000_00000000b
        DATA_SEG dd 0x0000ffff
                 dd 00000000_1_1_0_0_1111_1_00_1_0010_00000000b
        STACK_SEG dd 0x0000ffff
                  dd 00000000_1_1_0_0_1111_1_00_1_0010_00000000b
        VIDEO_SEG dd 0x80000007
                  dd 00000000_1_1_0_0_0000_1_00_1_0010_00001011b
        
        ;GDT定义结束

        
	GDT_SIZE equ $-GDT_BASE
        GDT_LIMIT equ GDT_SIZE-1
        times 60 dq 0
        SECTOR_CODE equ (0x0001<<3)+000b
        SECTOR_DATA equ (0x0002<<3)+000b
        SECTOR_STACK equ (0x0003<<3)+000b
        SECTOR_VIDEO equ (0x0004<<3)+000b
        
        gdt_ptr dw GDT_LIMIT 
                dd GDT_BASE
     
        
        str: db "Hello Os"

     loader_start:   
        mov bp,str
        mov cx,8
        mov ax,0x1301
        mov dx,0x1800
        mov bx,0x001f
        int 10h
        
        in al,0x92
        or al,0000_0010b
        out 0x92,al
        
        lgdt [gdt_ptr]
        
        mov eax,cr0
        or eax,0x0000_0001
        mov cr0,eax
        jmp dword  SECTOR_CODE:startPro
       
        [bits 32]
     startPro:   
         mov ax,SECTOR_DATA
         mov ds,ax
         mov es,ax
         mov ss,ax
         mov esp,LOADER_BASE_ADDR
         mov ax,SECTOR_VIDEO
         mov gs,ax
         mov byte [gs:00a0h],'P'
         jmp $
