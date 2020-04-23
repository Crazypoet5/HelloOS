#include "print.h"

#include  "stdint.h"

#include "bitmap.h"

#include "memory.h"
#include "assert.h"
#include "string.h"
struct mem_pool{

  

  uint32_t pool_size; //字节大小

  uint32_t pool_addr; //这块内存的起始地址

  struct bitmap pool_bitmap; //内存池的使用情况的位图，判断内存是否被占用
  int pool_flag;
};

struct mem_pool kernel_pool,user_pool;

//用来管理内核的虚拟地址
struct virtual_addr kernel_virtu_addr;

void mem_pool_init(int total_mem){
    //已经用过的内存字节数

    //4096是4kB，每个页表的大小

    //我们一共定义了255个页表，加上页目录表自己

    //再加上低端1MB的大小

    int used_mem=4096*256+0x100000;

    int free_mem=total_mem-used_mem;

    int free_pages=free_mem/4096;

    int kernel_pages=free_pages/2;

    int user_pages=free_pages-kernel_pages;

    //计算内核的内存字节大小

    kernel_pool.pool_size=kernel_pages*4096;

    //计算用户内存的字节大小

    user_pool.pool_size=user_pages*4096;

    //计算内核位图的长度

    //因为位图中每一位代表一页

    //长度的单位是字节共八位，因此

    kernel_pool.pool_bitmap.btmp_bytes_len=kernel_pages/8;

    //计算用户内存位图的长度    

    user_pool.pool_bitmap.btmp_bytes_len=user_pages/8;

    //内核内存的起始地址

    kernel_pool.pool_addr=used_mem;
    kernel_pool.pool_flag=1;

    //用户的内存起始地址

    user_pool.pool_addr=used_mem+kernel_pool.pool_size;

    //内核的位图起始地址设置为

    kernel_pool.pool_bitmap.bits=(void*)0xc009a000;

    //用户的位图起始地址

    user_pool.pool_bitmap.bits=(void*)(0xc009a000+kernel_pages/8);
    user_pool.pool_flag=0;
     /******************** 输出内存池信息 **********************/
        //内核位图起始地址
   	put_str("kernel_pool_bitmap_start:");
	put_int16((int)kernel_pool.pool_bitmap.bits);	
	put_str("\n");
        //内核位图长度
	put_str("kernel_pool_bitmap_length:");
	put_int16((int)kernel_pool.pool_bitmap.btmp_bytes_len);	
	put_str("\n");
        //内核内存的起始地址
	put_str("kernel_pool_phy_addr_start:");
	put_int16(kernel_pool.pool_addr);
	put_str("\n");
        //内核占用内存大小
        put_str("kernel_pool_byte_size:");
	put_int16(kernel_pool.pool_size);
	put_str("\n");
   	//用户位图起始地址
	put_str("user_pool_bitmap_start:");
	put_int16((int)user_pool.pool_bitmap.bits);
	put_str("\n");
        //用户位图长度
  put_str("user_pool_bitmap_length:");
	put_int16(user_pool.pool_bitmap.btmp_bytes_len);
	put_str("\n");
        //用户内存起始地址
	put_str("user_pool_phy_start:");
	put_int16(user_pool.pool_addr);
	put_str("\n");
        //用户占用内存字节大小
	put_str("user_pool_byte_size");
	put_int16(user_pool.pool_size);
	put_str("\n");



   /* 将位图置0*/

   //初始化位图

   bitmap_init(&kernel_pool.pool_bitmap);

   bitmap_init(&user_pool.pool_bitmap);



//    lock_init(&kernel_pool.lock);

//    lock_init(&user_pool.lock);



   /* 下面初始化内核虚拟地址的位图,按实际物理内存大小生成数组。*/

   kernel_virtu_addr.virtual_addr_bitmap.btmp_bytes_len = kernel_pool.pool_bitmap.btmp_bytes_len;   

      // 用于维护内核堆的虚拟地址,所以要和内核内存池大小一致




  //这个就是内存堆的起始地址
  //在低端1MB之外
   kernel_virtu_addr.virtual_addr_start=0xc0100000;  
/* 位图的数组指向一块未使用的内存,目前定位在内核内存池和用户内存池之外*/

   kernel_virtu_addr.virtual_addr_bitmap.bits=(void*)( 0xc009a000 + kernel_pages/8 + user_pages/8);
    
     bitmap_init(&kernel_virtu_addr.virtual_addr_bitmap);
     put_str("mem_pool_init done\n");

}

//获取count个连续的虚拟页
//必须确保虚拟地址要是连续的才行
//物理地址可以不连续，但是虚拟地址必须连续

void * get_virtual_addr(enum pool_flags pf,int count){
        //判断是那个内存池，如果是内核
        //那么在内核虚拟内存池中判断
        if(pf==PF_KERNEL){
         struct virtual_addr *pool=&kernel_virtu_addr;
          int index=bitmap_scan(&(pool->virtual_addr_bitmap),count);
          int temp=index;
            if(index==-1){
                 
                 return NULL;
             }
        while(count--){
            bitmap_set(&(pool->virtual_addr_bitmap),temp++,1);
        }
        return (void*) (index*4096+(uint32_t)pool->virtual_addr_start) ;
        }
        else{
          
        } 
  
}
//这个函数是用来获得一个虚拟地址的页表项的虚拟地址
//因为当我们分配内存的时候
//需要设置页表项
uint32_t * get_page_table_entry_addr(uint32_t old_virtual_addr){

        //由于我们对页表的设置，在页目录项中的最后一个页框中设置的是该页目录项自己的地址
        //一个页目录项有1024个页框
        //最后一个页框是偏移位为1023，十六进制0x3ff，移到最高十位是0xffc
        //因此该虚拟地址的高十位应该是0xffc才能访问到改页目录项的地址
        //页目录项的起始地址位0x100000
        //页目录项 中存放着页表的物理地址
       /*|1023| 存放地址为：0x100000
         |1022| ...                  
         | ...| ...
         | 2  | ...
         |  1 | ...
         |  0 | ...
       页表 
         |1023| 页表中存放的是普通物理页的物理地址
         |1022| ...                  
         | ...| ...
         | 2  | ...
         |  1 | ...
         |  0 | ...
        */
        //那么现在我们应该从页目录项中获取到页表的地址
        
        //因为对于一个虚拟地址来说
        //高十位就是页表在页目录项中的偏移量
        //因此我们取出old_old_virtual_addr的高十位放进new_virtual的中间十位即可
        
        //最后是获取页表中页表项的关键
        //思路和获取页表类似
        //但是我们需要右移十二位，且需要手动乘上偏移量       
        return (uint32_t*)((0xffc00000)+((old_virtual_addr&0xffc00000)>>10)+((old_virtual_addr&0x003ff000)>>12)*4);
}
//这个函数是用来获得一个虚拟地址的页目录项的虚拟地址
//因为当我们分配内存的时候
//需要设置页目录项
//也就是页表的地址，也是需要在程序运行过程中自动设置的
uint32_t * get_page_directory_entry_addr(uint32_t old_virtual_addr){
         
         //这里是获取虚拟地址的页表的虚拟地址
         //也就是说通过这个地址我们可以访问到在页目录项中的页表那个框
       //页目录项的起始地址位0x100000
       /*|1023| 存放地址为：0x100000
         |1022| ...
         | ...| ...
         | 2  | ...
         |  1 | ...
         |  0 | ...
         在这个1024个页表框中，其中最后一个也就是1023号页框中存放的地址正是该页目录表的起始地址
         //当一个虚拟地址的高十位是1023时，那么这个时候处理器会将这个页目录表当成页表来访问
         //当一个虚拟地址中间十位也是1023时，这时处理器将会把该页目录表当成普通的一个物理页来访问
         //所以new_virtual_addr的前20位应该是 1023 1023 ，换成十六进制就是0xfffff000
         //最后12位处理器会当成偏移地址来处理

         //最后12位应该设置成页表的在页目录项中的偏移量
         
         */   
        return (uint32_t*)((0xfffff000)+((old_virtual_addr&0xffc00000)>>22)*4);
}

//这个函数用来分配一页的的内存
//参数是一个内存池
//代表从这个池中选择一页内存分配出去
//考虑下面几个问题

//如何知道剩余内存还有没有一页

//如果有，那么如何得到这一页内存的起始地址

//并且让别人知道这一页内存已经被占用了

void * get_one_page(struct mem_pool * pool){
  //扫描一遍改内存池中的位图
  //判断是否还有剩余内存
  //如果有返回位图中的下标 
  int index=bitmap_scan(&(pool->pool_bitmap),1);
  //index为-1代表没有多余的内存
  //直接返回null
  if(index==-1){
      return NULL;
  }
  //如果有，那么将这一位设置为1，代表已经被占用           
  bitmap_set(&(pool->pool_bitmap),index,1);
  //返回该页的地址，因为位图中的每一位都代表一页，
  //所以这页的起始地址是index*4kb+内存池的起始地址
  return (void*)((index*4096)+ pool->pool_addr);
}
//从虚拟地址映射到物理地址
void virtual_map_physical(void * virtual_addr,void * physical_addr){
    
    uint32_t *pte=get_page_table_entry_addr((uint32_t)virtual_addr);
    uint32_t *pde=get_page_directory_entry_addr((uint32_t)virtual_addr);
    //如果页表存在
    //那么我们只要设置页表项就行了
    if((*pde&0x00000001)){
        //第一个设置的是页目录项的P位，告诉cpu这页存在内存中
        //第二个设置的是页目录项的权级
        //因为内核的pde早就已经由我们手动设置完成了，因此剩下的都是用用户级
        //第三个设置得是页目录项的读写项，这里肯定是要可读可写的
      ASSERT(!(*pte&0x00000001));
         //确保pte不存在
         if(!(*pte&0x00000001)){
            *pte=((uint32_t)physical_addr)|0x00000001|0x00000004|0x00000002;
         }
    }
    else{
        //如果页表不存在那么我们需要从物理内存中申请一页当作页表
        //页表一般是放在内核空间的
        //因此直接向内核申请
        //返回一个页表地址
        void* page_addr=get_one_page(&kernel_pool);
        //设置页目录项中的页表，
        *pde=((uint32_t)page_addr)|0x00000001|0x00000004|0x00000002;
        memset((void*)((uint32_t)pte&0xfffff000),0,4096);
        
        
        //当有了页表之后
        //就可以利用pte设置页表项了，
        //完成虚拟地址到物理地址的映射
         ASSERT(!(*pte&0x00000001));
         //确保pte不存在
         if(!(*pte&0x00000001)){
            *pte=((uint32_t)physical_addr)|0x000000001|0x00000004|0x00000002;
        }
    }
    
}
void * molloc_page(enum pool_flags pf,int count){      
    if(count==0)
           return NULL;
      void * vstart= get_virtual_addr(pf,count);
      uint32_t  virstual_start=(uint32_t)vstart;
      if(vstart==NULL){
          return NULL;
      }
      struct mem_pool *pool;
      if(pf==PF_KERNEL){
           pool=&kernel_pool;
      }
      else{
          pool=&user_pool;
      } 
    while(count--){
       void* physical_addr=get_one_page(pool);
       if(physical_addr==NULL){
           return NULL;
       }
       virtual_map_physical((void*)virstual_start,physical_addr);
       virstual_start+=4096;
    }
    return vstart;
}
void *get_kernel_page(uint32_t count){
  void * addr=molloc_page(PF_KERNEL,count);
  if(addr!=NULL){
      memset(addr,0,count*4096);
  }
  return addr;

}
void mem_init(){
    put_str("\nmem_init start:\n");
    put_str("memory_size:");
    put_int16((*(uint32_t*)(0x906))); 
    put_char('\n');
    //先将该地址转换成指针
    //再通过*取值
    //这个地址就是代表着总内存大小f
    mem_pool_init((*(uint32_t*)(0x906)));
    put_str("\nmem_init done\n");

}