#include "stdint.h"
#include "print.h"
#include "interrupt.h"
void panic_spin(char* filename, int line, const char* func, const char* condition){
    intr_disable();
    put_str("!!!!!! error\n");
   //打印文件名
    put_str("filename:");
    put_str(filename);
    put_str("\n");
   //打印行号 
    put_str("line:");
    put_int(line);
    put_str("\n");
 //打印函数名   
    put_str("func:");
    put_str(func);
    put_str("\n");
   //打印出错条件 
     put_str("condition:");
    put_str(condition);
    put_str("\n");
}
