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
     
        asrm_buf times 20 db 0
        memory: db 0x0000_0000
          
        str: db "Hello Os"
        strLength equ $-str
     loader_start: 
        Hello:  
        mov bp,str
        mov cx,strLength
        mov dx,0x0b24
        mov ax,0x1301
        mov bx,0x001f
        int 10h
        ;call print  

        mov ebx,0x0
        mov edx,0x534d_4150 
        mov di,asrm_buf
        mov esi,0h
        mov ebp,0
        detect_memory: 
            mov eax,0x0000_e820
            mov ecx,20
            int 0x15
            jc have_error  
            mov eax,[asrm_buf]
            mov ecx,[asrm_buf+8]
            cmp ecx,esi
            jbe get_max 
            mov ebp,eax
            mov esi,ecx
            mov [memory],esi
            cmp ebx,0 
            jz  protectModeReady
            loop detect_memory
                 
      ; print:   
      ;   mov ax,0x1301
      ;   mov bx,0x001f
      ;   int 10h
      ;   ret
     
      jmp protectModeReady      
      
      get_max:
           cmp ebx,0
           jz protectModeReady
           loop  detect_memory
        
   
      
      have_error:
        ErrorInfo: db "e802 code error"
        ErrorInfoLength equ $-ErrorInfo
        mov bp,ErrorInfo
        mov cx,ErrorInfoLength
        mov dx,0x0200
        mov ax,0x1301
        mov bx,0x001f
        int 10h  
       
    
         
      ;打开A20Gate  
    protectModeReady:
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
         mov ebp,memory
         mov si,00a0h
         mov cx,4
        print:
         mov dx,[es:ebp]
         mov [gs:si],dx
         inc si
         inc bp
         loop print
         jmp $
    
   