//
//  JNYJGCD.m
//  GCDYIET
//
//  Created by JNYJ on 14-11-22.
//  Copyright (c) 2014年 JNYJ. All rights reserved.
//

#import "JNYJGCD.h"

@implementation JNYJGCD


/*
 这两天在看《OC高级编程-多线程编程和内存管理》日本人写的那本，该书对arc，block和gcd有了更深层次的解读，非常不错。现在总结一下gcd相关的知识。有关arc和block的参考arc   参考block
 网上很多博客都对gcd有过讲解，很多是对gcd的全局队列，主线程队列，创建队列等等，做了单一功能描述，不是很全面系统。下面我们将学习一下系统得gcd。本文主要分为下面几个要点，前几个好点比较好理解，最后可能理解起来有些费劲！
 ● 什么是gcd，iOS为什么要用多线程
 ● 创建线程，序列线程和并发线程
 ● 系统默认的五个队列
 ● gcd的其他接口
 ● gcd的实现和dispatch source
 下面开始介绍第一个要点
 1. 什么是GCD
 gcd是异步执行任务的技术之一。一般将应用程序中记述的线程管理用的代码在系统级中实现。开发者只需要定义想执行的任务，并追加到适当的Dispatch Queue中，gcd就能生成必要的线程并计划执行任务。由于线程管理是系统级实现的。因此可以统一管理，可以执行任务，这样就比以前的线程更加有效——摘自Apple官方文档。
 在gcd出现之前，就有performSelector还有NSThread。但是performSelector比NSTread要简单，gcd比performSelector更加简单，一目了然。
 本书中给线程下了一个定义：1个CPU执行的CPU指令列为一条无分叉路径即为“线程”，如下图：

 多线程就是一个程序中有好几个这样的无分叉路径，如下图

 但是多线程是极易发生各种问题的技术，例如数据竞争，死锁，线程耗费大量内存等等。虽然极易出现问题，但是也应当使用多线程。因为多线程可以保证应用程序的响应性能。
 在iOS中App启动时，最先执行的线程就是主线程，它用来绘制UI，触摸屏幕的事件。如果在主线程中进行长时间的处理，就妨碍主线程的执行，从而导致UI卡顿。如下图

 2. 创建线程队列
 一般情况下，不需要手动创建线程队列，因为系统为了我们准备了2个队里（见下个要点）。
 这要说明一下Dispatch Queue，它是执行处理的等待队列。Dispatch Queue有两种类型，一个是Serial Dispatch Queue顺序队列，一个是Concurrent Dispatch Queue。这两个都很好理解，前者是串行队列，一个任务执行完毕，接着下个任务执行。Concurrent Dispatch Queue是并发队列，

 请看下面的代码：
 [objc] view plaincopy在CODE上查看代码片派生到我的代码片
 //dispatch_queue_t gcd = dispatch_queue_create("这是序列队列", NULL);
 dispatch_queue_t gcd = dispatch_queue_create("这是并发队列", DISPATCH_QUEUE_CONCURRENT);
 dispatch_async(gcd, ^{NSLog(@"b0");});
 dispatch_async(gcd, ^{NSLog(@"b1");});
 dispatch_async(gcd, ^{NSLog(@"b2");});
 dispatch_async(gcd, ^{NSLog(@"b3");});
 dispatch_async(gcd, ^{NSLog(@"b4");});
 dispatch_async(gcd, ^{NSLog(@"b5");});
 dispatch_async(gcd, ^{NSLog(@"b6");});
 dispatch_async(gcd, ^{NSLog(@"b7");});
 dispatch_async(gcd, ^{NSLog(@"b8");});
 dispatch_async(gcd, ^{NSLog(@"b9");});
 dispatch_async(gcd, ^{NSLog(@"b10");});
 dispatch_release(gcd);
 使用不同的Queue输出结果是不同的。如果是顺序队列，输出结果肯定是顺序的，如果使用并发队列，每次都不一样，下面是其中一个log：
 b1
 b0
 b4
 b3
 b2
 b5
 b6
 b7
 b8
 b9
 之所以Concurrent Dispatch Queue可以做到并发执行，是因为其使用了多个线程，就上面的输出，可能的方案如下：

 刚才的代码中已经使用dispatch_queue_create函数，看一下dispatch_queue_create的原型：
 [cpp] view plaincopy在CODE上查看代码片派生到我的代码片
 dispatch_queue_t
 dispatch_queue_create(const char *label, dispatch_queue_attr_t attr);
 这是一个C语言级别的函数。如果第二个参数是NULL表示顺序队列，如果是DISPATCH_QUEUE_CONCURRENT则是并发队列。通常一个多线程更新相同资源导致数据竞争的时候使用顺序队列，当想并行不发生数据竞争等问题的处理时，使用并发队列。
 注意：Dispatch Queue必须有程序员来释放。因为ARC不会应用到派发队列上。可以在create后立即调用dispatch_release();因为block持有这个队列。当block运行完毕，这个队列就自动释放了。
 3. 系统默认的五个队列
 实际上，系统会为我们创建几个队列，他们是Main Dispatch Queue和Global Dispatch Queue。系统提供的Dispatch Queue总结如下表

 下面是获取全局并发队列和主线程队列的代码
 [objc] view plaincopy在CODE上查看代码片派生到我的代码片
 //获取全局队列
 dispatch_queue_t mainQ = dispatch_get_main_queue();
 //获取高,中，低，后台优先级队列并发队列
 dispatch_queue_t globalH = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
 dispatch_queue_t globalD = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
 dispatch_queue_t globalL = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
 dispatch_queue_t globalB = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
 4. gcd的其他接口
 接口还是有那么几个，有些是常用的，有些则不太常用
 dispatch_set_target_queue——改变用dispatch_queue_create创建的队列的优先级
 dispatch_after——延时处理一段代码。
 ——这里展示了performSelector和dispatch_time的不同
 dispatch_group——并发队列中，所有的任务执行完成后，调用的代码。
 ——dispatch_group_wait和dispatch_group_notify的区别是：前者会阻塞当前线程，后面的代码没法并发执行了，而后者则不会阻塞当前线程。
 dispatch_barrier_async——栅栏作用。可以将并发队列中任务分成两部分。
 dispatch_sync——同步等待，当前队列全部执行完毕
 dispatch_apply——规定次数将指定block加入到dispatch_queue中，并等待全部处理执行结束。
 dispatch_suspend/dispatch_resume——挂起恢复指定线程队列
 dispatch_semaphore——从名字中可以发现“信号量”，该接口是对dispatch_barrier_async精细化处理
 dispatch_once——只执行一次的代码。通常用于单例
 dispatch I/O——如果想提高文件读取速度，可以尝试dispatch I/O
 具体的使用参考下面的代码。
 [objc] view plaincopy在CODE上查看代码片派生到我的代码片
 -(void) testGCD{
 [self testDispatch_target];
 [self testDispatch_after];
 [self testDispatch_Group];
 [self testDispatch_Barrier];
 [self testDispatch_sync];//在运行的时候，将这一行注释掉，不然就死锁了
 [self testDispatch_apply];
 [self testDispatch_once];
 }

// 可以改变dispatch_queue的优先级

-(void) testDispatch_target{
	dispatch_queue_t serial = dispatch_queue_create("xxxx",NULL);
	dispatch_queue_t queueG = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_set_target_queue(serial, queueG);
}

// testDispatch_after 延时添加到队列

-(void) testDispatch_after{
	dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 3*NSEC_PER_SEC);
	dispatch_after(time, dispatch_get_main_queue(), ^{
		NSLog(@"3秒后添加到队列");
	});
}

// dispatch_barrier_async 栅栏的作用

-(void) testDispatch_Barrier{
	//dispatch_queue_t gcd = dispatch_queue_create("这是序列队列", NULL);
	dispatch_queue_t gcd = dispatch_queue_create("这是并发队列", DISPATCH_QUEUE_CONCURRENT);
	dispatch_async(gcd, ^{NSLog(@"b0");});
	dispatch_async(gcd, ^{NSLog(@"b1");});
	dispatch_async(gcd, ^{NSLog(@"b2");});
	dispatch_async(gcd, ^{NSLog(@"b3");});
	dispatch_async(gcd, ^{NSLog(@"b4");});
	dispatch_barrier_async(gcd, ^{NSLog(@"barrier");});//dispatch_barrier_async
	dispatch_async(gcd, ^{NSLog(@"b5");});
	dispatch_async(gcd, ^{NSLog(@"b6");});
	dispatch_async(gcd, ^{NSLog(@"b7");});
	dispatch_async(gcd, ^{NSLog(@"b8");});
	dispatch_async(gcd, ^{NSLog(@"b9");});
	dispatch_async(gcd, ^{NSLog(@"b10");});
	dispatch_release(gcd);
}

// dispatch_sync.的三个操作

-(void) testDispatch_sync{
	//1. 同步等待
	dispatch_queue_t queueG = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_sync(queueG, ^{NSLog(@"dispatch_sync同步等待");});
	//2. 死锁
	dispatch_queue_t mainQ = dispatch_get_main_queue();
	dispatch_sync(mainQ, ^{NSLog(@"dispatch_sync同步等待,这么写是死锁");});
	//3. 同样是死锁
	dispatch_sync(mainQ, ^{
		dispatch_sync(mainQ, ^{NSLog(@"dispatch_sync同步等待,同样是死锁");});});
}

// dispatch Group的演示

-(void) testDispatch_Group{
	dispatch_queue_t mainQ = dispatch_get_main_queue();
	dispatch_queue_t queueG = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_group_t group = dispatch_group_create();
	dispatch_group_async(group, queueG, ^{NSLog(@"dispatch group blk1");});
	dispatch_group_async(group, queueG, ^{NSLog(@"dispatch group blk2");});
	dispatch_group_notify(group, mainQ, ^{NSLog(@"dispatch group");});
	dispatch_release(group);
}

// 按照指定次数将指定的block追加到指定的dispatch queue中。

-(void) testDispatch_apply{
	dispatch_queue_t queueG = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_apply(10, queueG, ^(size_t i){NSLog(@"%zu",i);});
	NSLog(@"done");
	//经典的做法是，循环一个数组
	NSArray* array = [NSArray arrayWithObjects:@1,@2,@3, nil nil];
	dispatch_apply([array count], queueG, ^(size_t i){
		NSLog(@"%ld", [array[i] integerValue]);
		;});
}

// 执行一次

-(void) testDispatch_once{
	static dispatch_once_t p;
	dispatch_once(&p,^{
		NSLog(@"testDispatch_once");
		;});
}
dispatch_suspend/dispatch_resume、dispatch_IO、dispatch_semaphore 这几个不太常用,就不再过多解释了
5. gcd的实现和dispatch source
本书中对gcd的实现不清楚，比较笼统和模糊。下面是一些介绍，gcd的实现依赖下面几个知识：
● 用于管理追加的Block的C语言层实现的FIFO队列
● Atomic函数中实现的用于排他控制的轻量级信号
● 用于管理线程的C语言实现的一些容器
当然除了上面说的工具外，gcd还需要内核级的一些实现。系统级中的一些软件组件比如：libdispatch实现Dispatch queue，Libc（pthreads）实现pthread_workqueue，XNU内核实现workqueue。
编程人员使用的gcd全部API都包含在libdispatch库中的c语言函数。dispatch queue通过结构体和链表实现FIFO队列，该队列管理这追加的block。
block并不是直接追加到FIFO中，而是先加入dispatch continuation这一dispatch_continuation_t类型结构体中，然后再假如FIFO队列。dispatch continuation用于记录block所属的一些信息，类似于执行上下文。
本书中以下部分描述了global dispatch queue 、Libc pthread_workqueue和XNU workqueue。书中的意思是，依次逐级调用。
下面说一下dispatch source
gcd中除了dispatch queue以外，还有不太引人注目的dispatch source 。它是BSD系惯有功能kqueue的包装。kqueue是在XNU内核中发生各种事件时，在应用程序编程方执行处理的技术。其cpu负荷小，尽量不占用资源。kqueue是应用程序处理XNU内核中发生的各种事件方法中最优秀的一种。
dispatch source可以取消，而dispatch queue不可以取消。

 */
+(void)loadData{
	//dispatch_queue_t gcd = dispatch_queue_create("这是序列队列", NULL);
	@autoreleasepool {

		dispatch_queue_t gcd = dispatch_queue_create("这是并发队列", DISPATCH_QUEUE_CONCURRENT);
//		dispatch_set_target_queue(dispatch_object_t object, dispatch_queue_t queue)
		dispatch_async(gcd, ^{NSLog(@"b0");});
		dispatch_async(gcd, ^{NSLog(@"b1");});
		dispatch_async(gcd, ^{NSLog(@"b2");});
		dispatch_async(gcd, ^{NSLog(@"b3");});
		dispatch_async(gcd, ^{NSLog(@"b4");});
		dispatch_async(gcd, ^{NSLog(@"b5");});
		dispatch_async(gcd, ^{NSLog(@"b6");});
		dispatch_async(gcd, ^{NSLog(@"b7");});
		dispatch_async(gcd, ^{NSLog(@"b8");});
		dispatch_async(gcd, ^{NSLog(@"b9");});
		dispatch_async(gcd, ^{NSLog(@"b10");});
	}

//	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//		NSURL * url = [NSURL URLWithString:@"http://avatar.csdn.net/2/C/D/1_totogo2010.jpg"];
//		NSData * data = [[NSData alloc]initWithContentsOfURL:url];
//		UIImage *image = [[UIImage alloc]initWithData:data];
//		if (data != nil) {
//			dispatch_async(dispatch_get_main_queue(), ^{
//				self.imageView.image = image;
//			});
//		}
//	});
}

/*
 http://blog.csdn.net/hherima/article/details/38901283
// iOS中timer相关的延时调用，常见的有NSObject中的performSelector:withObject:afterDelay:这个方法在调用的时候会设置当前runloop中timer，还有一种延时，直接使用NSTimer来配置任务。
// 这两种方式都一个共同的前提，就是当前线程里面需要有一个运行的runloop并且这个runloop里面有一个timer。
// 我们知道：只有主线程会在创建的时候默认自动运行一个runloop，并且有timer，普通的子线程是没有这些的。这样就带来一个问题了，有些时候我们并不确定我们的模块是不是会异步调用到，而我们在写这样的延时调用的时候一般都不会去检查运行时的环境，这样在子线程中被调用的时候，我们的代码中的延时调用的代码就会一直等待timer的调度，但是实际上在子线程中又没有这样的timer，这样我们的代码就永远不会被调到。
// 下面的代码展示了performSelector和dispatch_time的不同
// [objc] view plaincopy
//
// 采用gcd的方式 延时添加到队列

-(void) testDispatch_after{
	dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 3*NSEC_PER_SEC);
	dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_after(time, queue, ^{
		NSLog(@"3秒后添加到队列");
	});
	dispatch_release(queue);
}
-(void) testDelay{
	NSLog(@"testDelay被执行");
}

// dispatch_barrier_async 栅栏的作用

-(void) testDispatch_Barrier{
	//dispatch_queue_t gcd = dispatch_queue_create("这是序列队列", NULL);
	dispatch_queue_t gcd = dispatch_queue_create("这是并发队列", DISPATCH_QUEUE_CONCURRENT);
	dispatch_async(gcd, ^{
		NSLog(@"b0");
		//这个selector不会执行，因为线程中没有runloop
		[self performSelector:@selector(testDelay) withObject:nil afterDelay:3];
		//代码会执行，因为采用了gcd方式
		[self testDispatch_after];
	});
	dispatch_release(gcd);
}
在有多线程操作的环境中，这样performSelector的延时调用，其实是缺乏安全性的。我们可以用另一套方案来解决这个问题，就是使用GCD中的dispatch_after来实现单次的延时调用
另外有一个解决方案：
performSelector并不是没有办法保证线程安全。例如下面的代码就可以运行：
[objc] view plaincopy
[self performSelector:@selector(testDelay) onThread:[NSThread mainThread] withObject:nil waitUntilDone:NO];
指定了该selector在主线程中运行。
还有一个解决方案：
[objc] view plaincopy
[self performSelector:@selector(testDelay) withObject:nil afterDelay:3 inModes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
启动线程中runloop，因为每个线程就有个默认的runloop

 */
@end
