 

#import "OCSocketManage.h"
#pragma mark -
#pragma mark 私有函数
//回调
static void socketCommunicationReceiveData(void *delegate, struct OCSocket *selfSocket, NSData *rcvData);
static void socketCommunicationDidCanceld(void *delegate, struct OCSocket *selfSocket, CancelCode cancelRst);
//检测是否连接了网络
BOOL testNetworkExists(void)
{
    struct sockaddr_in zeroAddress;
	bzero(&zeroAddress, sizeof(zeroAddress));
	zeroAddress.sin_len = sizeof(zeroAddress);
	zeroAddress.sin_family = AF_INET;
	SCNetworkReachabilityRef defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&zeroAddress);
	SCNetworkReachabilityFlags flags;
	
	BOOL didRetrieveFlags = SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags);
	CFRelease(defaultRouteReachability);
	
	if (!didRetrieveFlags)
    {
		printf("网络异常,无法连接网络,请检查网络");
		return NO;
	}
	
	BOOL isReachable = flags & kSCNetworkFlagsReachable;
	BOOL needsConnection = flags & kSCNetworkFlagsConnectionRequired;
	return (isReachable && !needsConnection) ? YES : NO;
}

#pragma mark -
#pragma mark 回调函数 - 收发数据
void socketCommunicationReceiveData(void *delegate, struct OCSocket *selfSocket, NSData *rcvData)
{
    OCSocketManage *socketManage = getSocketManage();
    [socketManage->bufferMData appendData:rcvData];
    
    NSString *dataStr = [[[NSString alloc] initWithData:rcvData encoding:NSUTF8StringEncoding] autorelease];
    
    NSLog(@"返回数据%@ %zd",dataStr,[dataStr length]);
    
}
void socketCommunicationDidCanceld(void *delegate, struct OCSocket *selfSocket, CancelCode cancelRst)
{
    OCSocketManage *socketManage = getSocketManage();
    pthread_mutex_lock(&socketManage->socketMutex);
    if(socketManage->socketCom)
        free(socketManage->socketCom);
    socketManage->socketCom = NULL;
    pthread_mutex_unlock(&socketManage->socketMutex);
    pthread_testcancel();
    //当取消线程时，这句话将会导致以后调用Log永久阻塞（原因不明，所以上面加上testcancel）
    NSLog(@"与服务器的连接已经关闭！");
}
#pragma mark -
#pragma mark 基本实现
OCSocketManage *getSocketManage(void)
{
    static OCSocketManage *socketManage = nil;
    if(!socketManage)
    {
        socketManage = malloc(sizeof(OCSocketManage));
        bzero(socketManage, sizeof(OCSocketManage));
        
        socketManage->socketCom = NULL;
        if(pthread_mutex_init(&socketManage->socketMutex, NULL))
            NSLog(@"锁初始化失败");
        if(pthread_cond_init(&socketManage->socketCond, NULL))
            NSLog(@"条件初始化失败");
    }
    return socketManage;
}

//参数设置
void OCSocketManageSetNetworkParameter(char *ipAddress, int port, int conTimeOut, int recvTimeOut)
{
    OCSocketManage *socketManage = getSocketManage();
    
    socketManage->connectIPAddress = ipAddress;
    socketManage->connectPort = port;
    socketManage->connectTimeOut = conTimeOut;
    socketManage->receiveTimeOut = recvTimeOut;
}
//设置延时时间
void OCSocketManageSetNetworkParameterTimer(int recvTimeOut)
{
    OCSocketManage *socketManage = getSocketManage();
    
    socketManage->receiveTimeOut = recvTimeOut;
}

#pragma mark -
#pragma mark 连接处理，读写数据
//检测socket
BOOL OCSocketManageTestConnect(void)
{
    return getSocketManage()->socketCom? YES: NO;
}
//连接
OCSM_Error OCSocketManageConnect(void)
{
    if(testNetworkExists() == NO){
        return SM_NoNetwork;
    }
    OCSocketManage *socketManage = getSocketManage();
    socketManage->socketCom = OCSocketCreateWithInformation(socketManage->connectIPAddress,
                                                            socketManage->connectPort,
                                                            socketManage->connectTimeOut,
                                                            socketManage,
                                                            socketCommunicationReceiveData,
                                                            socketCommunicationDidCanceld);
    if(socketManage->socketCom)
    {
        //连接成功须要对缓冲区做处理
        [socketManage->bufferMData release];
        socketManage->bufferMData = [[NSMutableData alloc] init];
        return SM_Success;
    }else
        return SM_ConnectFail;
}
//连接主服务器
OCSM_Error OCSocketManageMasterServerConnect(void)
{
    if(testNetworkExists() == NO)
    {
        return SM_NoNetwork;
    }
    OCSM_Error resultError = SM_Success;
    
    NSString *str;
    str = getIPAddressForHost(@"www.4g-alarm.com");
    if (!str)
    {
        return resultError = SM_NoNetwork;
    }
    OCSocketManageSetNetworkParameter((char*)[str UTF8String], 30010, 10, 10);
    if(OCSocketManageTestConnect() == NO)
    {
        resultError = OCSocketManageConnect();
        if(resultError != SM_Success)
        {
            return resultError;
        }
    }
    return resultError;
}

#pragma mark 处理后台
//后台掉
void OCSocketManageProcessBackground(void)
{
    OCSocketManageCloseConnect();
    //同时唤醒等待线程
    pthread_cond_signal(&getSocketManage()->socketCond);
}

//重连（检测断开并重连）
OCSM_Error OCSocketManageReconnectLogin(void)
{
    OCSM_Error smError = SM_Success;
    if(!OCSocketManageTestConnect())
    {
        if(testNetworkExists() == NO){
            return SM_NoNetwork;
        }
    }
    return smError;
}

//2.23添加，完成发送线程的发送数据并等待唤醒的工作
OCSM_Error OCSocketManageSendDataAndWaitResult(OCSocketManage *socketManage, NSData *data, id *rstObj)
{
    NSString *str = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"\n\n发送数据：%@\n%zd",str,[str length]);
    pthread_mutex_lock(&socketManage->socketMutex);
    OCSM_Error backError = SM_Success;
    if(socketManage->socketCom == NULL){
        NSLog(@"socketManage->socketCom 为空");
        backError = SM_WriteFail;
        goto OCFunReturn;
    }
    if(OCSocketWriteData(socketManage->socketCom, data) != YES){
        OCSocketManageCloseConnect();
        backError = SM_WriteFail;
        goto OCFunReturn;
    }
    if (33==[str length]){
        NSString *sting =[str substringWithRange:NSMakeRange(28,3)];
        if ([sting isEqualToString:@"030"]){
            socketManage->waitTime.tv_sec = [NSDate date].timeIntervalSince1970 +25;
            goto OCAddFitt;
        }
    }
    socketManage->waitTime.tv_sec = [NSDate date].timeIntervalSince1970 +socketManage->receiveTimeOut;
OCAddFitt:
    [str release];
    socketManage->waitTime.tv_nsec = 0;
    
    NSLog(@"开始等待");
    int y = pthread_cond_timedwait(&socketManage->socketCond, &socketManage->socketMutex, &socketManage->waitTime);
    NSLog(@"%d",y);
    NSLog(@"结束等待");
    
    //拷贝数据
    if(socketManage->resultObject)
    {
        //用可变赋值回传数据
        if ([[socketManage->resultObject class] isSubclassOfClass:[NSNumber class]])
        {
            *rstObj = [NSNumber numberWithBool:[socketManage->resultObject boolValue]];
        }else
        {
            *rstObj = [[socketManage->resultObject mutableCopy] autorelease];
        }
        [socketManage->resultObject release];
        socketManage->resultObject = nil;
    }else
    {
        *rstObj = NULL;
        backError = SM_NoData;
    }
OCFunReturn:
    pthread_mutex_unlock(&socketManage->socketMutex);
    return backError;
}

void OCSocketManageCloseConnect(void)
{
    if(OCSocketManageTestConnect())
    {
        OCSocketManage *socketManage = getSocketManage();
        socketManage->isRequestClose = YES; //请求关闭
        OCSocketClostConnect(socketManage->socketCom);
        free(socketManage->socketCom);
        socketManage->socketCom = NULL;
    }
}
//从NSMutableData中读取数据，读出的数据将会被删除
NSData *readFromMutableData(NSMutableData **mDataPointer, NSUInteger readLength)
{
    if(readLength > [*mDataPointer length])
    {
        NSLog(@"请求读入的数据过多");//异常
        return NULL;
    }
    NSData *readData;
    if(readLength < [*mDataPointer length])
    {
        readData = [*mDataPointer subdataWithRange:NSMakeRange(0, readLength)];
        NSData *restData = [*mDataPointer subdataWithRange:NSMakeRange(readLength, [*mDataPointer length]-readLength)];
        *mDataPointer = nil;
        *mDataPointer = [[NSMutableData alloc] initWithData:restData];
    }else
    {
        readData = [[*mDataPointer copy] autorelease];
        *mDataPointer = nil;
        *mDataPointer = [[NSMutableData alloc] init];
    }
    return readData;
}

//获取命令标记（可修改其实现）
void OCSocketManageSetCommandMark(void)
{
    OCSocketManage *socketManage = getSocketManage();
    
#ifdef OCDebug
    memcpy(socketManage->commandMark, "8888", 4);
    return;
#endif
    //获取当前时间
    NSDate *now = [NSDate date];

    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSUInteger unitFlags = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    NSDateComponents *dateComponent = [calendar components:unitFlags fromDate:now];
    

    NSInteger minute = [dateComponent minute];
    NSInteger second = [dateComponent second];
    
    static char timeStrings[5] = {0};
    snprintf(timeStrings, 5, "%02zd%02zd",minute,second);
    memcpy(socketManage->commandMark, timeStrings, 4);
}
//主服务器返回的特殊验证
BOOL OCSocketManageCompareSeverAndAwakenSendThread(const char *rcvCmdMark,id resultObj)
{
    OCSocketManage *socketManage = getSocketManage();
    
    [socketManage->resultObject release];
    socketManage->resultObject = [resultObj retain];
    NSLog(@"开始唤醒");
    pthread_cond_signal(&socketManage->socketCond);
    NSLog(@"结束唤醒");
    
    return YES;
}

//判断命令标记，并赋值，唤醒主线程
BOOL OCSocketManageCompareCmdMarkAndAwakenSendThread(const char *rcvCmdMark,id resultObj)
{
    OCSocketManage *socketManage = getSocketManage();
    BOOL cmdMarkSame = bcmp(socketManage->commandMark, rcvCmdMark, 4)==0?YES:NO;
    
    if(cmdMarkSame)
    {
        [socketManage->resultObject release];
        socketManage->resultObject = [resultObj retain];
        NSLog(@"开始唤醒");
        pthread_cond_signal(&socketManage->socketCond);
        NSLog(@"结束唤醒");
    }else
    {
        [resultObj release];
    }
    
    return cmdMarkSame;
}
//从缓存中读取数据
NSData *OCSocketManageReadData(NSUInteger readLength)
{
    OCSocketManage *sockM = getSocketManage();
    return readFromMutableData(&sockM->bufferMData, readLength);
}
NSString *OCSocketManageAutoReadString(void)
{
    NSString *readLenStr = [[[NSString alloc] initWithData:OCSocketManageReadData(2) encoding:NSUTF8StringEncoding] autorelease];
    NSData *stringData = OCSocketManageReadData([readLenStr intValue]);
    return [[[NSString alloc] initWithData:stringData encoding:NSUTF8StringEncoding] autorelease];
}
//从缓存中读取给定长度的数据，并转化为字符串
NSString *OCSocketManageReadString(int strLen)
{
    NSData *readData = OCSocketManageReadData(strLen);
    return [[[NSString alloc] initWithData:readData encoding:NSUTF8StringEncoding] autorelease];
}
//从NSMutableData中读取字符串
NSString *readStringFromMutableData(NSMutableData **mDataPointer, NSUInteger readLength)
{
    NSData *stringData = readFromMutableData(mDataPointer, readLength);
    return [[[NSString alloc] initWithData:stringData encoding:NSUTF8StringEncoding] autorelease];
}
