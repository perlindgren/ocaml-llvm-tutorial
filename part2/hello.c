/* compile with: clang -emit-llvm -c hello.c -o hello.bc */
#include <stdio.h>

int main(void)
{
    int c = 0;
    int d = c + 1;
    printf("hello, world\n");

    return 0;
}
