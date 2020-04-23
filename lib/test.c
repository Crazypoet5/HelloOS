#include <stdio.h>
struct test{
  int x;
  int y;
  char* str;
};
void init(struct test *i){
   printf("%s",i->str);
   printf("%d",1);
}
void main(){
 
struct test *tt;
tt->str="123";
init(tt);
printf("%d",2);

}
