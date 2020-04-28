#include "thread.h"

#include "memory.h"

#include "string.h"

#include "print.h"

#include "list.h"

#include "assert.h"

#include "interrupt.h"

struct task_struct * main_the;

struct list ready_thread;

struct list all_thread; 

extern void switch_to(struct task_struct * cur,struct task_struct *next);

void schedule(){

     struct task_struct * current_task=get_running_pcb_addr();

     if(current_task->status==TASK_RUNNING){

          current_task->status=TASK_READY;

          current_task->tricks=current_task->priority;

          ASSERT(!elem_find(&ready_thread,&(current_task->thread_tag_ready)));

          list_append(&ready_thread,&(current_task->thread_tag_ready));
          struct list_elem * thread_tag=list_pop(&ready_thread);
          struct task_struct *next_task=(struct task_struct *)(((uint32_t)thread_tag)&(0xfffff000));

          next_task->status=TASK_RUNNING;

          switch_to(current_task,next_task);



     }



}

//获取当前正在运行的线程的地址

 struct task_struct * get_running_pcb_addr(){

    uint32_t addr=0;

     asm volatile ("movl %%esp,%0;":"=(g)"(addr));

     //我们得到当前线程的栈地址后

     //因为栈地址一定是在某个页中

     //它的后12位是在页中的偏移

     //前20就是pcb的地址了

     //所以会有下面的与操作

     addr=addr&(0xfffff000);

     return (struct task_struct *)(addr);

}

void function_start(thread_func * function,void *arg){

     intr_enable();

     function(arg);

}

void init_thread_stack(struct task_struct *sss,thread_func function,void *arg){

  //这里保留中断栈的空间在最顶端

   sss->self_kstack-=sizeof(struct intr_stack);

  //这里保留 线程栈的空间，方便将来保存上下文环境 

   sss->self_kstack -=sizeof(struct thread_stack);

   //

   struct thread_stack *sts=(struct thread_stack * )sss->self_kstack;

  

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

        //线程的名称

        sss->name=name;

        //线程的权限用来控制执行时间

        sss->priority=priority;

        //该线程的栈的指针，设置为当前页的最大值

        sss->self_kstack=(uint32_t*)((uint32_t)sss+4096);

        //线程的运行状态

        if(sss==main_the){

          sss->status=TASK_RUNNING;

        }

        else{

          sss->status=TASK_READY;

        }

        //检测线程内存是否越界

        sss->stack_magic=0x19283474;

        //线程发生的中断数

        sss->tricks=priority;

        //线程的虚拟地址

        sss->pcb_addr=NULL;

        //判断线程是否已经在队列中了

     



}

//专门用来初始化主线程的

void  main_thread(){

//初始化主线程的pcb

main_the=get_running_pcb_addr();

init_task_struct(main_the,"main",20);

 ASSERT(!elem_find(&all_thread,&(main_the->thread_tag_all)));

 list_append(&all_thread,&(main_the->thread_tag_all));



}
// 

struct task_struct * create_thread(thread_func function,char *name,int priority,void*arg){

     struct task_struct *sss=(struct task_struct*)get_kernel_pages(1);

    init_task_struct(sss,name, priority); 

    init_thread_stack(sss,function,arg);

    ASSERT(!elem_find(&all_thread,&(sss->thread_tag_all)));

   list_append(&all_thread,&(sss->thread_tag_all));

     

     ASSERT(!elem_find(&ready_thread,&(sss->thread_tag_ready)));

    

    list_append(&ready_thread,&(sss->thread_tag_ready));



      return sss;

}

void init_thread(){

 put_str("thread_init start");

 list_init(&ready_thread);

list_init(&all_thread);

main_thread();

}