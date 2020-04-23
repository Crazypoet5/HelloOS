#include "global.h"
#include "io.h"
#include "print.h"
#include "init.h"
#include "assert.h"
void main(){
    put_str("Hello,kernel\n");
    init_all();
    ASSERT(1==2);
    while(1);
}