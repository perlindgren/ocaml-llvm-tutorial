/* compile with: clang -emit-llvm -c hello.c -o hello.bc */
#include <stdio.h>

int main(void)
{
	int a;
	a = a + 1;

	printf("hello, world %d\n", a);

	return 0;
}
