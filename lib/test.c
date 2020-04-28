#include <stdio.h>
typedef void thread_func(void*);

void func1(int * a){
 printf("%d",*a);
}
struct a{
  int a;
  void (*xxx);
  int c;
};

void init( struct a *t,int x){
  
  t->a=x;
  t->c=x;  
}
void main(){
    
     struct a t;
     init(&t,1);
     printf("%d\n",&t);
     printf("%d",(struct a*)0x00000001);
}