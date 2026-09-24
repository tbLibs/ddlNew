//
//  NoaIMSignalExceptionHandler.m
//  CIMSDKCore
//
//  Created by Candy on 2023/5/17.
//

#import "NoaIMSignalExceptionHandler.h"
#include <libkern/OSAtomic.h>
#include <execinfo.h>
#import "NoaIMLoganManager.h"

const NSInteger UncaughtExceptionHandlerSkipAddressCount = 4;
const NSInteger UncaughtExceptionHandlerReportAddressCount = 5;

void customSignalExceptionHandler(int signal) {
    
    NSMutableString *mutableStr = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:@"Signal %d :", signal]];
    
    void* callstack[128];
    int i = backtrace(callstack, 128);
    char ** strs = backtrace_symbols(callstack, 128);
    for (i = 0; i < sizeof(strs); i++) {
        [mutableStr appendFormat:@"%s\n", strs[i]];
    }
    
    //保存到日志模块
    NSMutableDictionary *loganDict = [NSMutableDictionary dictionary];
    [loganDict setValue:mutableStr forKey:@"exceptionInfo"];
    [[NoaIMLoganManager sharedManager] writeLoganWith:LingIMLoganTypeException loganContent:[[NoaIMLoganManager sharedManager] configLoganContent:loganDict]];
    
    //保存到本地
    //NSString *signalPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingString:@"/SignalException.txt"];
    //[mutableStr writeToFile:signalPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
}

@implementation NoaIMSignalExceptionHandler

#pragma mark - Signal
+ (void)setSignalExceptionHandler {
    //信号量截断
    
    signal(SIGHUP, customSignalExceptionHandler);
    signal(SIGINT, customSignalExceptionHandler);
    signal(SIGQUIT, customSignalExceptionHandler);
    signal(SIGABRT, customSignalExceptionHandler);
    signal(SIGILL, customSignalExceptionHandler);
    signal(SIGSEGV, customSignalExceptionHandler);
    signal(SIGFPE, customSignalExceptionHandler);
    signal(SIGBUS, customSignalExceptionHandler);
    signal(SIGPIPE, customSignalExceptionHandler);
}
+ (NSArray *)backtrace {
    void* callstack[128];
    int frames = backtrace(callstack, 128);//用于获取当前线程的函数调用堆栈，返回实际获取的指针个数
    char **strs = backtrace_symbols(callstack, frames);//从backtrace函数获取的信息转化为一个字符串数组
    int i;
    NSMutableArray *backtrace = [NSMutableArray arrayWithCapacity:frames];
    for (i = UncaughtExceptionHandlerSkipAddressCount;
     i < UncaughtExceptionHandlerSkipAddressCount+UncaughtExceptionHandlerReportAddressCount;
     i++)  {
        [backtrace addObject:[NSString stringWithUTF8String:strs[i]]];
    }
    free(strs);
    return backtrace;
}

//signal类型
 
// define SIGHUP 1 /* hangup */
//
// SIGHUP是Unix系统管理员很常用的一个信号。许多后台服务进程在接受到该信号后将会重新读取它们的配置文件。然而，该信号的实际功能是通知进程它的控制终端被断开。缺省行为是终止进程。
//
// define SIGINT 2 /* interrupt */
//
// 对于Unix使用者来说，SIGINT是另外一个常用的信号。许多shell的CTRL-C组合使得这个信号被大家所熟知。该信号的正式名字是中断信号。缺省行为是终止进程。
//
// define SIGQUIT 3 /* quit */
//
// SIGQUIT信号被用于接收shell的CTRL-/组合。另外，它还用于告知进程退出。这是一个常用信号，用来通知应用程序从容的（译注:即在结束前执行一些退出动作）关闭。缺省行为是终止进程，并且创建一个核心转储。
//
// define SIGILL 4 /* illegal instr. (not reset when caught) */
//
// 如果正在执行的进程中包含非法指令，操作系统将向该进程发送SIGILL信号。如果你的程序使用了线程，或者pointer functions，那么可能的话可以尝试捕获该信号来协助调试。（[color=Red]注意：原文这句为：“If your program makes use of use of threads, or pointer functions, try to catch this signal if possible for aid in debugging.”。中间的两个use of use of，不知是原书排版的瑕疵还是我确实没有明白其意义；另外，偶经常听说functions pointer，对于pointer functions，google了一下，应该是fortran里面的东西，不管怎样，还真不知道，确切含义还请知道的兄弟斧正。[/color]）缺省行为是终止进程，并且创建一个核心转储。
//
// define SIGTRAP 5 /* trace trap (not reset when caught) */
//
// SIGTRAP这个信号是由POSIX标准定义的，用于调试目的。当被调试进程接收到该信号时，就意味着它到达了某一个调试断点。一旦这个信号被交付，被调试的进程就会停止，并且它的父进程将接到通知。缺省行为是终止进程，并且创建一个核心转储。
//
// define SIGABRT 6 /* abort() */
//
// SIGABRT提供了一种在异常终止(abort)一个进程的同时创建一个核心转储的方法。然而如果该信号被捕获，并且信号处理句柄没有返回，那么进程不会终止。缺省行为是终止进程，并且创建一个核心转储。
//
// define SIGFPE 8 /* floating point exception */
//
// 当进程发生一个浮点错误时，SIGFPE信号被发送给该进程。对于那些处理复杂数学运算的程序，一般会建议你捕获该信号。缺省行为是终止进程，并且创建一个核心转储。
//
// define SIGKILL 9 /* kill (cannot be caught or ignored) */
//
// SIGKILL是这些信号中最难对付的一个。正如你在它旁边的注释中看到的那样，这个信号不能被捕获或忽略。一旦该信号被交付给一个进程，那么这个进程就会终止。然而，会有一些极少数情况SIGKILL不会终止进程。这些罕见的情形在处理一个“非中断操作”（比如磁盘I/O）的时候发生。虽然这样的情形极少发生，然而一旦发生的话，会造成进程死锁。唯一结束进程的办法就只有重新启动了。缺省行为是终止进程。
//
// define SIGBUS 10 /* bus error */
//
// 如同它的名字暗示的那样，CPU检测到数据总线上的错误时将产生SIGBUS信号。当程序尝试去访问一个没有正确对齐的内存地址时就会产生该信号。缺省行为是终止进程，并且创建一个核心转储。
//
// define SIGSEGV 11 /* segmentation violation */
//
// SIGSEGV是另一个C/C++程序员很熟悉的信号。当程序没有权利访问一个受保护的内存地址时，或者访问无效的虚拟内存地址（脏指针，dirty pointers，译注：由于没有和后备存储器中内容进行同步而造成。关于野指针，可以参见http://en.wikipedia.org/wiki/Wild_pointer 的解释。）时，会产生这个信号。缺省行为是终止进程，并且创建一个核心转储。
//
// define SIGSYS 12 /* non-existent system call invoked */
//
// SIGSYS信号会在进程执行一个不存在的系统调用时被交付。操作系统会交付该信号，并且进程会被终止。缺省行为是终止进程，并且创建一个核心转储。
//
// define SIGPIPE 13 /* write on a pipe with no one to read it */
//
// 管道的作用就像电话一样，允许进程之间的通信。如果进程尝试对管道执行写操作，然而管道的另一边却没有回应者时，操作系统会将SIGPIPE信号交付给这个讨厌的进程（这里就是那个打算写入的进程）。缺省行为是终止进程。
//
// define SIGALRM 14 /* alarm clock */
//
// 在进程的计时器到期的时候，SIGALRM信号会被交付（delivered）给进程。这些计时器由本章后面将会提及
// 的setitimer和alarm调用设置。缺省行为是终止进程。
//
// define SIGTERM 15 /* software termination signal from kill */
//
// SIGTERM信号被发送给进程，通知该进程是时候终止了，并且在终止之前做一些清理活动。SIGTERM信号是Unix的kill命令发送的缺省信号，同时也是操作系统关闭时向进程发送的缺省信号。缺省行为是终止进程。
//
// define SIGURG 16 /* urgent condition on IO channel */
//
// 在进程已打开的套接字上发生某些情况时，SIGURG将被发送给该进程。如果进程不捕获这个信号的话，那么将被丢弃。缺省行为是丢弃这个信号。
//
// define SIGSTOP 17 /* sendable stop signal not from tty */
//
// 本信号不能被捕获或忽略。一旦进程接收到SIGSTOP信号，它会立即停止(stop)，直到接收到另一个SIGCONT
// 信号为止。缺省行为是停止进程，直到接收到一个SIGCONT信号为止。
//
// define SIGTSTP 18 /* stop signal from tty */
//
// SIGSTP与SIGSTOP类似，它们的区别在于SIGSTP信号可以被捕获或忽略。当shell从键盘接收到CTRL-Z的时候就会交付（deliver）这个信号给进程。缺省行为是停止进程，直到接收到一个SIGCONT信号为止。
//
// define SIGCONT 19 /* continue a stopped process */
//
// SIGCONT也是一个有意思的信号。如前所述，当进程停止的时候，这个信号用来告诉进程恢复运行。该信号的有趣的地方在于：它不能被忽略或阻塞，但可以被捕获。这样做很有意义：因为进程大概不愿意忽略或阻塞SIGCONT信号，否则，如果进程接收到SIGSTOP或SIGSTP的时候该怎么办？缺省行为是丢弃该信号。
//
// define SIGCHLD 20 /* to parent on child stop or exit */
//
// SIGCHLD是由Berkeley Unix引入的，并且比SRV 4 Unix上的实现有更好的接口。（如果信号是一个没有追溯能力的过程(not a retroactive process)，那么BSD的SIGCHID信号实现会比较好。在system V Unix的实现中，如果进程要求捕获该信号，操作系统会检查是否存在有任何未完成的子进程（这些子进程是已经退出exit)的子进程，并且在等待调用wait的父进程收集它们的状态）。如果子进程退出的时候附带有一些终止信息(terminating information），那么信号处理句柄就会被调用。所以，仅仅要求捕获这个信号会导致信号处理句柄被调用(译注：即是上面说的“信号的追溯能力”)，而这是却一种相当混乱的状况。）一旦一个进程的子进程状态发生改变，SIGCHLD信号就会被发送给该进程。就像我在前面章节提到的，父进程虽然可以fork出子进程，但没有必要等待子进程退出。一般来说这是不太好的，因为这样的话，一旦进程退出就可能会变成一个僵尸进程。可是如果父进程捕获SIGCHLD信号的话，它就可以使用wait系列调用中的某一个去收集子进程状态，或者判断发生了什么事情。当发送SIGSTOP,SIGSTP或SIGCONF信号给子进程时，SIGCHLD信号也会被发送给父进程。缺省行为是丢弃该信号。
//
// define SIGTTIN 21 /* to readers pgrp upon background tty read */
//
// 当一个后台进程尝试进行一个读操作时，SIGTTIN信号被发送给该进程。进程将会阻塞直到接收到SIGCONT信号为止。缺省行为是停止进程，直到接收到SIGCONT信号。
//
// define SIGTTOU 22 /* like TTIN if (tp->t_local&LTOSTOP) */
//
// SIGTTOU信号与SIGTTIN很相似，不同之处在于SIGTTOU信号是由于后台进程尝试对一个设置了TOSTOP属性的tty执行写操作时才会产生。然而，如果tty没有设置这个属性，SIGTTOU就不会被发送。缺省行为是停止进程，直到接收到SIGCONT信号。
//
// define SIGIO 23 /* input/output possible signal */
//
// 如果进程在一个文件描述符上有I/O操作的话，SIGIO信号将被发送给这个进程。进程可以通过fcntl调用来设置。缺省行为是丢弃该信号。
//
// define SIGXCPU 24 /* exceeded CPU time limit */
//
// 如果一旦进程超出了它可以使用的CPU限制（CPU limit），SIGXCPU信号就被发送给它。这个限制可以使用随后讨论的setrlimit设置。缺省行为是终止进程。
//
// define SIGXFSZ 25 /* exceeded file size limit */
//
// 如果一旦进程超出了它可以使用的文件大小限制，SIGXFSZ信号就被发送给它。稍后我们会继续讨论这个信号。缺省行为是终止进程。
//
// define SIGVTALRM 26 /* virtual time alarm */
//
// 如果一旦进程超过了它设定的虚拟计时器计数时，SIGVTALRM信号就被发送给它。缺省行为是终止进程。
//
// define SIGPROF 27 /* profiling time alarm */
//
// 当设置了计时器时，SIGPROF是另一个将会发送给进程的信号。缺省行为是终止进程。
//
// define SIGWINCH 28 /* window size changes */
//
// 当进程调整了终端的行或列时（比如增大你的xterm的尺寸），SIGWINCH信号被发送给该进程。缺省行为是丢弃该信号。
//
// define SIGUSR1 29 /* user defined signal 1 */
//
// define SIGUSR2 30 /* user defined signal 2 */
//
// SIGUSR1和SIGUSR2这两个信号被设计为用户指定。它们可以被设定来完成你的任何需要。换句话说，操作系统没有任何行为与这两个信号关联。缺省行为是终止进程。(译注：按原文的意思翻译出来似乎这两句话有点矛盾。)

@end
