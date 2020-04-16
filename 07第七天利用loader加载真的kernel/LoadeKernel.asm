   ;loader的使命
;设置段描述符，加载gdt，进入保护模式
;设置页表，使用虚拟页表   
;加载内核：需要把内核文件加载到内存缓冲区。
;初始化内核：需要在分页后，将加载进来的 elf 内核文件安置到相应的虚拟内存地址，
;然后跳过去执行，从此 loader 的工作结束。
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
        SELECTOR_CODE equ (0x0001<<3)+000b
        SELECTOR_DATA equ (0x0002<<3)+000b
        SELECTOR_STACK equ (0x0003<<3)+000b
        SELECTOR_VIDEO equ (0x0004<<3)+000b
        
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
        jmp dword  SELECTOR_CODE:startPro
       
        [bits 32]
     startPro:   
         mov ax,SELECTOR_DATA
         mov ds,ax
         mov es,ax
         mov ss,ax
         mov esp,LOADER_BASE_ADDR
         mov ax,SELECTOR_VIDEO
         mov gs,ax
         -------------------------   加载kernel  ----------------------
         mov eax, KERNEL_START_SECTOR        ; kernel.bin所在的扇区号
         mov ebx, KERNEL_BIN_BASE_ADDR       ; 从磁盘读出后，写入到ebx指定的地址
         mov ecx, 200			       ; 读入的扇区数
         call rd_disk_m_32
         
         call set_up
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
         ;;;;;;;;;;;;;;;;;;;;;;;;;;;;  此时不刷新流水线也没问题  ;;;;;;;;;;;;;;;;;;;;;;;;
;由于一直处在32位下,原则上不需要强制刷新,经过实际测试没有以下这两句也没问题.
;但以防万一，还是加上啦，免得将来出来莫句奇妙的问题.
        jmp SELECTOR_CODE:enter_kernel	  ;强制刷新流水线,更新gdt
        enter_kernel:    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        call kernel_init
        mov esp, 0xc009f000
        jmp KERNEL_ENTRY_POINT                 ; 用地址0x1500访问测试，结果ok


;-----------------   将kernel.bin中的segment拷贝到编译的地址   -----------
kernel_init:
   xor eax, eax
   xor ebx, ebx		;ebx记录程序头表地址
   xor ecx, ecx		;cx记录程序头表中的program header数量
   xor edx, edx		;dx 记录program header尺寸,即e_phentsize

   mov dx, [KERNEL_BIN_BASE_ADDR + 42]	  ; 偏移文件42字节处的属性是e_phentsize,表示program header大小
   mov ebx, [KERNEL_BIN_BASE_ADDR + 28]   ; 偏移文件开始部分28字节的地方是e_phoff,表示第1 个program header在文件中的偏移量
					  ; 其实该值是0x34,不过还是谨慎一点，这里来读取实际值
   add ebx, KERNEL_BIN_BASE_ADDR
   mov cx, [KERNEL_BIN_BASE_ADDR + 44]    ; 偏移文件开始部分44字节的地方是e_phnum,表示有几个program header
.each_segment:
   cmp byte [ebx + 0], PT_NULL		  ; 若p_type等于 PT_NULL,说明此program header未使用。
   je .PTNULL

   ;为函数memcpy压入参数,参数是从右往左依然压入.函数原型类似于 memcpy(dst,src,size)
   push dword [ebx + 16]		  ; program header中偏移16字节的地方是p_filesz,压入函数memcpy的第三个参数:size
   mov eax, [ebx + 4]			  ; 距程序头偏移量为4字节的位置是p_offset
   add eax, KERNEL_BIN_BASE_ADDR	  ; 加上kernel.bin被加载到的物理地址,eax为该段的物理地址
   push eax				  ; 压入函数memcpy的第二个参数:源地址
   push dword [ebx + 8]			  ; 压入函数memcpy的第一个参数:目的地址,偏移程序头8字节的位置是p_vaddr，这就是目的地址
   call mem_cpy				  ; 调用mem_cpy完成段复制
   add esp,12				  ; 清理栈中压入的三个参数
.PTNULL:
   add ebx, edx				  ; edx为program header大小,即e_phentsize,在此ebx指向下一个program header 
   loop .each_segment
   ret

;----------  逐字节拷贝 mem_cpy(dst,src,size) ------------
;输入:栈中三个参数(dst,src,size)
;输出:无
;---------------------------------------------------------
mem_cpy:		      
   cld
   push ebp
   mov ebp, esp
   push ecx		   ; rep指令用到了ecx，但ecx对于外层段的循环还有用，故先入栈备份
   mov edi, [ebp + 8]	   ; dst
   mov esi, [ebp + 12]	   ; src
   mov ecx, [ebp + 16]	   ; size
   rep movsb		   ; 逐字节拷贝

   ;恢复环境
   pop ecx		
   pop ebp
   ret

   mov byte [gs:00a0h],'P'
   mov byte[gs:140h],'V'
   jmp $
    ;分页启动
set_up:
        mov ecx,4096
        mov esi,0
    clear_zeor:
        mov byte [PAGE_DIR_START_ADDR+esi],0
        inc esi
        loop clear_zeor
    creat_page_dir:
        mov eax,0
        mov eax,0x111
        add eax,PAGE_TABLE_START_ADDR
        mov [PAGE_DIR_START_ADDR],eax
        mov [PAGE_DIR_START_ADDR+0xc00],eax
        
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
 ;-------------------------------------------------------------------------------
			   ;功能:读取硬盘n个扇区
rd_disk_m_32:	   
;-------------------------------------------------------------------------------
							 ; eax=LBA扇区号
							 ; ebx=将数据写入的内存地址
							 ; ecx=读入的扇区数
      mov esi,eax	   ; 备份eax
      mov di,cx		   ; 备份扇区数到di
;读写硬盘:
;第1步：设置要读取的扇区数
      mov dx,0x1f2
      mov al,cl
      out dx,al            ;读取的扇区数

      mov eax,esi	   ;恢复ax

;第2步：将LBA地址存入0x1f3 ~ 0x1f6

      ;LBA地址7~0位写入端口0x1f3
      mov dx,0x1f3                       
      out dx,al                          

      ;LBA地址15~8位写入端口0x1f4
      mov cl,8
      shr eax,cl
      mov dx,0x1f4
      out dx,al

      ;LBA地址23~16位写入端口0x1f5
      shr eax,cl
      mov dx,0x1f5
      out dx,al

      shr eax,cl
      and al,0x0f	   ;lba第24~27位
      or al,0xe0	   ; 设置7～4位为1110,表示lba模式
      mov dx,0x1f6
      out dx,al

;第3步：向0x1f7端口写入读命令，0x20 
      mov dx,0x1f7
      mov al,0x20                        
      out dx,al

;;;;;;; 至此,硬盘控制器便从指定的lba地址(eax)处,读出连续的cx个扇区,下面检查硬盘状态,不忙就能把这cx个扇区的数据读出来

;第4步：检测硬盘状态
  .not_ready:		   ;测试0x1f7端口(status寄存器)的的BSY位
      ;同一端口,写时表示写入命令字,读时表示读入硬盘状态
      nop
      in al,dx
      and al,0x88	   ;第4位为1表示硬盘控制器已准备好数据传输,第7位为1表示硬盘忙
      cmp al,0x08
      jnz .not_ready	   ;若未准备好,继续等。

;第5步：从0x1f0端口读数据
      mov ax, di	   ;以下从硬盘端口读数据用insw指令更快捷,不过尽可能多的演示命令使用,
			   ;在此先用这种方法,在后面内容会用到insw和outsw等

      mov dx, 256	   ;di为要读取的扇区数,一个扇区有512字节,每次读入一个字,共需di*512/2次,所以di*256
      mul dx
      mov cx, ax	   
      mov dx, 0x1f0
  .go_on_read:
      in ax,dx		
      mov [ebx], ax
      add ebx, 2
			  ; 由于在实模式下偏移地址为16位,所以用bx只会访问到0~FFFFh的偏移。
			  ; loader的栈指针为0x900,bx为指向的数据输出缓冲区,且为16位，
			  ; 超过0xffff后,bx部分会从0开始,所以当要读取的扇区数过大,待写入的地址超过bx的范围时，
			  ; 从硬盘上读出的数据会把0x0000~0xffff的覆盖，
			  ; 造成栈被破坏,所以ret返回时,返回地址被破坏了,已经不是之前正确的地址,
			  ; 故程序出会错,不知道会跑到哪里去。
			  ; 所以改为ebx代替bx指向缓冲区,这样生成的机器码前面会有0x66和0x67来反转。
			  ; 0X66用于反转默认的操作数大小! 0X67用于反转默认的寻址方式.
			  ; cpu处于16位模式时,会理所当然的认为操作数和寻址都是16位,处于32位模式时,
			  ; 也会认为要执行的指令是32位.
			  ; 当我们在其中任意模式下用了另外模式的寻址方式或操作数大小(姑且认为16位模式用16位字节操作数，
			  ; 32位模式下用32字节的操作数)时,编译器会在指令前帮我们加上0x66或0x67，
			  ; 临时改变当前cpu模式到另外的模式下.
			  ; 假设当前运行在16位模式,遇到0X66时,操作数大小变为32位.
			  ; 假设当前运行在32位模式,遇到0X66时,操作数大小变为16位.
			  ; 假设当前运行在16位模式,遇到0X67时,寻址方式变为32位寻址
			  ; 假设当前运行在32位模式,遇到0X67时,寻址方式变为16位寻址.

      loop .go_on_read
      ret