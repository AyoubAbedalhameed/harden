#include <stdio.h>
#include <stdlib.h>
#include <sys/resource.h>

int main(int argc, char** argv) {
	system(argv[1]);	/*pass the argument to system to run as a child process*/

	struct rusage ru;	/*struct will be passed to getrusage() to get output from*/
	getrusage(RUSAGE_CHILDREN, &ru);	/*RUSAGE_CHILDREN tells getrusage() to get the info of the child processes intead of the main*/

	/*print the retreived info in a human readable way*/
	printf("\nblock input operations (inblock):\t%li pages\n", ru.ru_inblock);
	printf("block output operations (oublock):\t%li pages\n", ru.ru_oublock);
	printf("maximum resident set size (maxrss):\t%li KB\n", ru.ru_maxrss);
	printf("user CPU time used (utime):\t%li seconds\t%li milliseconds\n", ru.ru_utime.tv_sec, ru.ru_utime.tv_usec);
	printf("system CPU time used (stime):\t%li seconds\t%li milliseconds\n", ru.ru_stime.tv_sec, ru.ru_stime.tv_usec);
//	printf("integral shared memory size (ixrss):\t%li\t/*This field is currently unused on Linux.*/\n", ru.ru_ixrss);	/*This field is currently unused on Linux.*/
//	printf("integral unshared data size (idrss):\t%li\t/*This field is currently unused on Linux.*/\n", ru.ru_idrss);	/*This field is currently unused on Linux.*/
//	printf("integral unshared stack size (isrss):\t%li\t/*This field is currently unused on Linux.*/\n", ru.ru_isrss);	/*This field is currently unused on Linux.*/
	printf("page reclaims (soft page faults) (minflt):\t%li\n", ru.ru_minflt);
	printf("page faults (hard page faults) (majflt):\t%li\n", ru.ru_majflt);
//	printf("swaps (nswap):\t%li\t/*This field is currently unused on Linux.*/\n", ru.ru_nswap);	/*This field is currently unused on Linux.*/
//	printf("IPC messages sent (msgsnd):\t%li\t/*This field is currently unused on Linux.*/\n", ru.ru_msgsnd);	/*This field is currently unused on Linux.*/
//	printf("IPC messages received (msgrcv:\t%li\t/*This field is currently unused on Linux.*/\n)", ru.ru_msgrcv);	/*This field is currently unused on Linux.*/
//	printf("signals received (nsignals):\t%li\t/*This field is currently unused on Linux.*/\n", ru.ru_nsignals);	/*This field is currently unused on Linux.*/
	printf("voluntary context switches (nvcsw):\t%li\n", ru.ru_nvcsw);
	printf("involuntary context switches (nivcsw):\t%li\n", ru.ru_nivcsw);
}
