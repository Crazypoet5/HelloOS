#include "stdint.h"

#include "global.h"

#include "io.h"

#include "print.h"
#include "interrupt.h"
#define IDT_length 33

#define PIC_M_CTRL 0x20	       // 这里用的可编程中断控制器是8259A,主片的控制端口是0x20

#define PIC_M_DATA 0x21	       // 主片的数据端口是0x21

#define PIC_S_CTRL 0xa0	       // 从片的控制端口是0xa0

#define PIC_S_DATA 0xa1
#define elflags_IF 0x00000200	                   // 从片的数据端口是0xa1
#define get_elflags(status) asm volatile("pushf,popf %0":"=b"(status))   
struct IDT_desc_arr{

    uint16_t low_offest;

    uint16_t seclector;

    uint8_t  remain;

    uint8_t  attr;

    uint16_t high_offest;

};

static struct IDT_desc_arr IDT[IDT_length];
void * IDT_handle_function[IDT_length];
char * interuption_name[IDT_length];
extern void * enter_IDT_Addr[IDT_length];

/* 初始化可编程中断控制器8259A */

static void pic_init(void) {



   /* 初始化主片 */

   outb (PIC_M_CTRL, 0x11);   // ICW1: 边沿触发,级联8259, 需要ICW4.

   outb (PIC_M_DATA, 0x20);   // ICW2: 起始中断向量号为0x20,也就是IR[0-7] 为 0x20 ~ 0x27.

   outb (PIC_M_DATA, 0x04);   // ICW3: IR2接从片. 

   outb (PIC_M_DATA, 0x01);   // ICW4: 8086模式, 正常EOI



   /* 初始化从片 */

   outb (PIC_S_CTRL, 0x11);    // ICW1: 边沿触发,级联8259, 需要ICW4.

   outb (PIC_S_DATA, 0x28);    // ICW2: 起始中断向量号为0x28,也就是IR[8-15] 为 0x28 ~ 0x2F.

   outb (PIC_S_DATA, 0x02);    // ICW3: 设置从片连接到主片的IR2引脚

   outb (PIC_S_DATA, 0x01);    // ICW4: 8086模式, 正常EOI

   

  /* IRQ2用于级联从片,必须打开,否则无法响应从片上的中断

  主片上打开的中断有IRQ0的时钟,IRQ1的键盘和级联从片的IRQ2,其它全部关闭 */

   outb (PIC_M_DATA, 0xfe);



/* 打开从片上的IRQ14,此引脚接收硬盘控制器的中断 */

   outb (PIC_S_DATA, 0xff);



   put_str("pic_init done\n");

}

static void Idt_init(struct IDT_desc_arr *idt,uint8_t attr,uint32_t enter_IDT_Addr){
//这里开始对结构体初始化

//本来low_offest是16位的，然后enter_Idt_Addr是32位的，发生了隐式转换之后，

//高16位会被截掉，保留低16位

//但是高16位本来就没有什么用

//因此可以不用处理

 idt->low_offest=(enter_IDT_Addr)&0x0000ffff;

 idt->seclector=SELECTOR_K_CODE;

 idt->remain=0;

 idt->attr=attr;

 //但是这里的高16位是需要保留住的，

 //因此我们需要右移16位

 idt->high_offest=((enter_IDT_Addr)&0xffff0000)>>16;

}

static void Idt_arr_init(){



    for(int i=0;i<IDT_length;i++){

        Idt_init(&IDT[i],IDT_DESC_ATTR_DPL0,(uint32_t)enter_IDT_Addr[i]);
 }
    


}


void normal_exception(uint8_t verctor_num){
    if(verctor_num==0x27||verctor_num==0x2f){
        return;
    }
   put_str(interuption_name[verctor_num]);
   put_str("\n");
   return;
}
void IDT_function_init(){
 for(int i=0;i<IDT_length;i++){
      IDT_handle_function[i]=normal_exception;    
      interuption_name[i]="unKnow";
  };
   interuption_name[0] = "#DE Divide Error";
   interuption_name[1] = "#DB Debug Exception";
   interuption_name[2] = "NMI Interrupt";
   interuption_name[3] = "#BP Breakpoint Exception";
   interuption_name[4] = "#OF Overflow Exception";
   interuption_name[5] = "#BR BOUND Range Exceeded Exception";
   interuption_name[6] = "#UD Invalid Opcode Exception";
   interuption_name[7] = "#NM Device Not Available Exception";
   interuption_name[8] = "#DF Double Fault Exception";
   interuption_name[9] = "Coprocessor Segment Overrun";
   interuption_name[10] = "#TS Invalid TSS Exception";
   interuption_name[11] = "#NP Segment Not Present";
   interuption_name[12] = "#SS Stack Fault Exception";
   interuption_name[13] = "#GP General Protection Exception";
   interuption_name[14] = "#PF Page-Fault Exception";
   // interuption_name[15] 第15项是intel保留项，未使用
   interuption_name[16] = "#MF x87 FPU Floating-Point Error";
   interuption_name[17] = "#AC Alignment Check Exception";
   interuption_name[18] = "#MC Machine-Check Exception";
   interuption_name[19] = "#XF SIMD Floating-Point Exception";
}
uint32_t intr_get_status(){
         uint32_t status=0;
         asm volatile("pushfl; popl %0":"=b"(status));
         return (status&elflags_IF) ?1:0;
}
uint32_t intr_enable(){
    if(intr_get_status()==1){
        return 1;
    }
    else{
        asm volatile("sti");
        return 0;
    }
}
uint32_t intr_disable(){
    if(intr_get_status()==0){
        return 0;
    }
    else{
        asm volatile("cli":::"memory");
        return 1;
    }
}
uint32_t intr_set_status(uint32_t status){
     return status & 1 ? intr_enable():intr_disable();
}
void idt_init(){

    

    Idt_arr_init();
    pic_init();
    IDT_function_init();
    //前面是32位的基址

    //后面是16位的段界限

    //为了保证数据不发生错误

    //只有先将IDT转换成64位

    //然后左移16位，数据才不会丢失

    uint64_t idt_limit_Base=(((uint64_t)((uint32_t)IDT))<<16)|(sizeof(IDT)-1);

    asm ("lidt %0"::"m"(idt_limit_Base));

    put_str("IDT_init done\n");

}
