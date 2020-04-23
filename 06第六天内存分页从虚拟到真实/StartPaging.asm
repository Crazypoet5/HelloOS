     %include "boot.inc"  
section loader vstart=LOADER_BASE_ADDR
        jmp loader_start
        ;GDT开始定义
        
        ;开始定义段描述符，为接下来进入保护模式作准备
        ;
        GDT_BASE dd 0x00000000
                 dd 0x00000000
        CODE_SEG dd 0x0000ffff
                 dd  00000000_1_1_0_0_1111_1_00_1_1000_00000000b
        DATA_SEG dd 0x0000ffff
                 dd 00000000_1_1_0_0_1111_1_00_1_0010_00000000b
        STACK_SEG dd 0x0000ffff
                  dd 00000000_1_1_0_0_1111_1_00_1_0010_00000000b
        VIDEO_SEG dd 0x80000007
                  dd 11000000_1_1_0_0_0000_1_00_1_0010_00001011b
        
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
         ; -------------------------   加载kernel  ----------------------
        mov eax, KERNEL_START_SECTOR        ; kernel.bin所在的扇区号
        mov ebx, KERNEL_BIN_BASE_ADDR       ; 从磁盘读出后，写入到ebx指定的地址
        mov ecx, 200			       ; 读入的扇区数

        call rd_disk_m_32

         call set_up
         ;保存GDT
         sgdt [gdt_ptr]
         
         add dword [gdt_ptr+2],0xc000_0000
      
         add esp,0xc000_0000
         ;cr3寄存器
         mov eax,PAGE_DIR_START_ADDR
         mov cr3,eax
         
         mov eax ,cr0 
         or eax,0x8000_0000
         mov cr0,eax

         lgdt [gdt_ptr]
         mov byte [gs:00a0h],'P'
         mov byte[gs:140h],'V'

         jmp $
       
       
         ;分页启动
         ;这里建造的是一个二级页表
         ;从页目录，到页表，再到物理地址
    set_up:
        ;4kb的十进制就是4096
        mov ecx,4096
        mov esi,0

        ;将第一个4kb的每个字节清零
        ;我们的目录项就是在这4kb中
        ;也就是初始化我们的页目录项
    clear_zeor:
        mov byte [PAGE_DIR_START_ADDR+esi],0 ;这个PAGE_DIR_START_ADDR就是我们页目录存在的起始地址大小是4kb
        inc esi                              ;因为一共有1024项，每项4b
        loop clear_zeor
        ;清零结束

     ;开始给页目录中的每项填充地址以及所需属性   
    creat_page_dir:
        mov eax,0
    ;这个0x111实际上代表着页目录项中的属性
        mov eax,0x111
    ;这个是页表地址    
        add eax,PAGE_TABLE_START_ADDR
        
            
        mov [PAGE_DIR_START_ADDR],eax
        mov [PAGE_DIR_START_ADDR+0xc00],eax
    ;在最后一个页目录表中填上当前页目录表的地址  
        sub eax ,0x1000
        mov [PAGE_DIR_START_ADDR+4092],eax
       
        ;创建核心的页表目录
        ;从3GB开始
        mov ecx,254
        mov esi, 0xc04
        add eax,0x2000
    creat_core_page_dir:
        mov [PAGE_DIR_START_ADDR+esi],eax 
        
        add eax,0x1000
        add esi,4
        loop creat_core_page_dir
     
    
    ;创建256个页表项
    ;为了映射到到最开始的0-1MB 
    ;且保持虚拟地址等于物理地址
        
        mov ecx,256
        mov esi,0
        ;111是为了控制页表项中的属性
        mov esi,0x111
        mov ebp,0
    creat_page_pro:
        mov [PAGE_TABLE_START_ADDR+ebp],esi
        add esi,0x1000        
        add ebp,4
       loop creat_page_pro 
    ;创建结束    
       ret
