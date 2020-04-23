

[bits 32]

%define ERROR_CODE nop

%define ZERO push 0
extern IDT_handle_function

extern put_str

section .data

    strat_str db "start hadle interrupt",0xa0,0

    global enter_IDT_Addr 
enter_IDT_Addr:
%macro VECTOR 2
section .text

   enter%1Addr:
            %2

            push es
            push ss
            push cs
            push gs
            pushad
            mov al,0x20 ;令eoi位为1，0x0010_0000,代表结束中断
            out 0xa0,al ;写入主片端口
            out 0x20,al ;写入从片端口
            push %1
            call [IDT_handle_function+%1*4]
            jmp interrupt_handel_over
            section .data 
                dd   enter%1Addr

    %endmacro 

VECTOR 0x00,ZERO

VECTOR 0x01,ZERO

VECTOR 0x02,ZERO

VECTOR 0x03,ZERO 

VECTOR 0x04,ZERO

VECTOR 0x05,ZERO

VECTOR 0x06,ZERO

VECTOR 0x07,ZERO 

VECTOR 0x08,ERROR_CODE

VECTOR 0x09,ZERO

VECTOR 0x0a,ERROR_CODE

VECTOR 0x0b,ERROR_CODE 

VECTOR 0x0c,ZERO

VECTOR 0x0d,ERROR_CODE

VECTOR 0x0e,ERROR_CODE

VECTOR 0x0f,ZERO 

VECTOR 0x10,ZERO

VECTOR 0x11,ERROR_CODE

VECTOR 0x12,ZERO

VECTOR 0x13,ZERO 

VECTOR 0x14,ZERO

VECTOR 0x15,ZERO

VECTOR 0x16,ZERO

VECTOR 0x17,ZERO 

VECTOR 0x18,ERROR_CODE

VECTOR 0x19,ZERO

VECTOR 0x1a,ERROR_CODE

VECTOR 0x1b,ERROR_CODE 

VECTOR 0x1c,ZERO

VECTOR 0x1d,ERROR_CODE

VECTOR 0x1e,ERROR_CODE

VECTOR 0x1f,ZERO 

VECTOR 0x20,ZERO	;时钟中断对应的入口
interrupt_handel_over:
    add esp ,4 ;跳过参数
    popad
    pop gs
    pop cs
    pop ss
    pop es
    add esp ,4   ;跳过错误码
    iret