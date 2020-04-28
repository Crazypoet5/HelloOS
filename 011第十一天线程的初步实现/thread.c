#include "thread.h"
#include "mem.h"
#include "string.h"
#include "print.h"
void function_start(thread_func * function,void *arg){
    function(arg);
}
void init_thread_stack(struct task_struct *sss,thread_func function,void *arg){
   sss->self_kstack-=sizeof(struct intr_stack);
    
   sss->self_kstack -=sizeof(struct thread_stack);
   struct thread_stack *sts=(struct thread_stack * )sss->self_kstack;
   put_int16((uint32_t)sts);
    put_char('\n');
   //栈顶一定要是待执行函数的地址
   sts->eip=function_start;
   sts->function=function;
   sts->func_arg=arg;
   sts->ebp=0;
   sts->ebx=0;
   sts->edi=0;
   sts->esi=0;

}
void init_task_struct(struct task_struct * sss,char *name,int priority){
        memset(sss,0,sizeof(*sss));
        sss->name=name;
        sss->priority=priority;
        sss->self_kstack=(uint32_t*)((uint32_t)sss+4096);
        sss->status=TASK_RUNNING;
        sss->stack_magic=0x19283474;
}
struct task_struct * init_thread(thread_func function,char *name,int priority,void*arg){
     struct task_struct *sss=(struct task_struct*)get_kernel_pages(1);
     put_int16((uint32_t)sss);
     put_char('\n');
     put_int16((uint32_t)function);
     put_char('\n');
    
     init_task_struct(sss,name, priority); 

put_int16((uint32_t)sss->self_kstack);
     put_char('\n');
    
 init_thread_stack(sss,function,arg);
      put_int16((uint32_t)sss->self_kstack);
  put_char('\n');
     asm volatile(
     "movl %0,%%esp;\n\t"
     "pop %%ebp;\n\t"
     "pop %%ebx;\n\t"
     "pop %%edi;\n\t"
     "pop %%esi;\n\t"
     "ret;\n\t"::"g"(sss->self_kstack):"memory");
     //当执行返回指令时，栈顶的值就是要返回的地址
     //此内存中的情况是这样的
     //其实内存中保存的就是thread_stack结构体的信息，按地址从低到高 
    /* |     |
       |     |
       |     | functionh函数的参数 参数2
       |     | function函数地址 参数1
       |     | 占位的4返回地址
       |     | eip    
     * |     | esi
     * |     | edi
     * |     | ebx
esp->* |     | ebp  栈顶位置
     */
     //当我们弹栈操作后
    /* |     |
       |     |
       |     | functionh函数的参数 参数2
       |     | function函数地址 参数1
       |     | 占位的4返回地址
  esp->|     | eip    
     */
    //此时栈顶是eip中保存function_start的地址，指令正常执行时。会跳转过去执行该函数
    //执行函数时内存是这样的
    /* |     |
       |     |
       |     | functionh函数的参数 参数2
       |     | function函数地址 参数1 
 esp-> |     | 占位的4返回地址
      */
     //栈顶这个返回地址虽然不起作用，但是也是必不可少的
     //如果没有它势必会导致，参数错误  
      return sss;
}