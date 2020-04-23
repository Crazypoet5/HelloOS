

#include "stdint.h"
#include "bitmap.h"
#include "assert.h"
void bitmap_init(struct bitmap* btmp){
    for(int i=0;i<btmp->btmp_bytes_len;i++){
          btmp->bits[i]=0;
    }
}
bool bitmap_scan_test(struct bitmap* btmp, uint32_t bit_idx){
    
    uint32_t x=bit_idx/(sizeof(char*));
    //防止越界
    ASSERT(x<btmp->btmp_bytes_len);
    uint32_t y=bit_idx%(sizeof(char*));
    //判断第x个数组中的第y位为1还是为0
    //如果为1说明该内存被占用
    //为0说明该内存空闲
    return (btmp->bits[x])&(1<<y)?true:false;
}
int bitmap_scan(struct bitmap* btmp, uint32_t cnt){
        int count=0;
        int start=-1;
     for(int i=0;i<btmp->btmp_bytes_len*8;i++){
           if(!bitmap_scan_test(btmp,i)){
               count++;
               if(count==cnt){
                   return i-cnt+1;
               }
           }
           else{
               count=0;
           }
       }
    return start;
}
void bitmap_set(struct bitmap* btmp, uint32_t bit_idx, int8_t value){
    uint32_t x=bit_idx/(sizeof(char*));
    //防止越界
    ASSERT(x<btmp->btmp_bytes_len);
    uint32_t y=bit_idx%(sizeof(char*));
    //对第x个字节进行操作
    //如果第x个字节
    if(value){
        btmp->bits[x]|=(0x1<<y);
    }
    else{
        btmp->bits[x]&=~(0x1<<y);
    }
}

    


