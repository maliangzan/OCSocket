
#import "OCSocket.h"
#define ReadMax 4096

struct OCSocket
{
    int sockfd;
    pthread_t socketThread;
    void *delegate;
    socketReceiveDataCallback receiveDataCallBack;
    socketDidCanceledCallBack canceledCallBack;
};

#pragma mark -
#pragma mark 私有函数声明
static void *readFromNetwork(void *socket);

static int connect_tcp(int socket_num,const char *ip,uint16_t port);

NSString *getIPAddressForHost(NSString *theHost)
{
    NSLog(@"连接的IP地址:%@",theHost);
    struct hostent *host = gethostbyname([theHost UTF8String]);
    if (!host) {herror("resolv"); return NULL; }
    struct in_addr **list = (struct in_addr **)host->h_addr_list;
    NSString *addressString = [NSString stringWithCString:inet_ntoa(*list[0]) encoding:NSUTF8StringEncoding];
    return addressString;
}

#pragma mark 函数
OCSocket *OCSocketCreateWithInformation(const char *hostIPStr, short port, int time, void *theDelegate, socketReceiveDataCallback receiveCB, socketDidCanceledCallBack canceledCB)
{
    OCSocket *createSocket = malloc(sizeof(OCSocket));
    createSocket->delegate = theDelegate;
    createSocket->receiveDataCallBack = receiveCB;
    createSocket->canceledCallBack = canceledCB;

    struct sockaddr_in serverAddr;
    bzero(&serverAddr, sizeof(serverAddr));
    createSocket->sockfd = socket(AF_INET, SOCK_STREAM, 0);
    
    serverAddr.sin_family = AF_INET;
    serverAddr.sin_addr.s_addr = inet_addr(hostIPStr);
    serverAddr.sin_port = htons(port);
    
    
    
    if(connect_tcp(createSocket->sockfd, hostIPStr, port) < 0)
    {
        free(createSocket);
        return NULL;
    }else  //开辟线程，执行读流
    {
        pthread_create(&createSocket->socketThread, NULL, readFromNetwork, createSocket);
    }
    return createSocket;
}


BOOL OCSocketWriteData(OCSocket *selfSocket, NSData *data)
{
    size_t needWrite = [data length];
    size_t didWriten;
    
    const char *dataPtr = [data bytes];
    const char *currentPtr = dataPtr;
    
    while (needWrite > 0)
    {
        didWriten = write(selfSocket->sockfd, currentPtr, needWrite);
        if (didWriten <= 0)
        {
            if((int)didWriten<0 && errno==EINTR)
                didWriten = 0;  //被信号中断
            else
                return NO;
        }
        needWrite -= didWriten;
        currentPtr += didWriten;
    }
    return YES;
}


void OCSocketClostConnect(OCSocket *selfSocket)
{
    pthread_cancel(selfSocket->socketThread);
    sleep(1);
    close(selfSocket->sockfd);
    //等待线程结束
    pthread_join(selfSocket->socketThread, NULL);
}

#pragma mark 私有函数
static void *readFromNetwork(void *socket)
{
    OCSocket *selfSocket = socket;
    while (1)
    @autoreleasepool
    {
        char readBuff[ReadMax];
        bzero(readBuff, ReadMax);
        NSInteger readCount = read(selfSocket->sockfd, readBuff, ReadMax);
        switch (readCount)
        {
            case -1:
                NSLog(@"-1Socket断开");
                selfSocket->canceledCallBack(selfSocket->delegate, selfSocket, readError);
                return NULL;
            
            case 0:
                NSLog(@"-2Socket断开");
                selfSocket->canceledCallBack(selfSocket->delegate, selfSocket, serverClose);
                return NULL;
        }
        pthread_testcancel();
        NSData *data = [NSData dataWithBytes:readBuff length:readCount];
        selfSocket->receiveDataCallBack(selfSocket->delegate, selfSocket, data);
    }
    
    return NULL;
}

static int connect_tcp(int socket_num,const char *ip,uint16_t port)
{
    struct timeval tv_out;
    tv_out.tv_sec = 10;
    tv_out.tv_usec = 0;
    setsockopt(socket_num, SOL_SOCKET, SO_RCVTIMEO, (char *)&tv_out, sizeof(struct timeval));
    
    tv_out.tv_sec = 5;
    tv_out.tv_usec = 0;
    setsockopt(socket_num, SOL_SOCKET, SO_SNDTIMEO, (char *)&tv_out, sizeof(struct timeval));
    
    int   savefl   =   fcntl(socket_num,F_GETFL);
    fcntl(socket_num,F_SETFL,savefl | O_NONBLOCK);
    
    struct sockaddr_in socketParameters;
    socketParameters.sin_family = AF_INET;
    socketParameters.sin_addr.s_addr = inet_addr(ip);
    socketParameters.sin_port = htons(port);
    int ret = connect(socket_num, (struct sockaddr *) &socketParameters, sizeof(socketParameters));
    if (ret == 0)
    {
        printf( "connected..1\n ");
        return 0;
    }
    if(errno != EINPROGRESS){
        close(socket_num);
        perror( "connect..2 ");
        return   -1;
    }
    fd_set set;
    FD_ZERO(&set);
    FD_SET(socket_num, &set);
    struct timeval timeo =   {10,0};
    int retval = select(socket_num + 1,   NULL,   &set,   NULL,   &timeo);
    if   (retval   ==   -1)
    {
        close(socket_num);
        printf( "select\n");
        return   -1;
    }
    else   if(retval   ==   0)
    {
        close(socket_num);
        printf( "connect timeout\n");
        return   -2;
    }
    
    if(FD_ISSET(socket_num,&set))
    {
        int   error   =   0;
        socklen_t   len   =   sizeof   (error);
        if(getsockopt(socket_num, SOL_SOCKET, SO_ERROR, &error, &len) < 0)
        {
            printf   ( "getsockopt  fail,connected  fail\n ");
            return   -1;
        }
        if(error == ETIMEDOUT)
        {
            printf( "connected timeout\n ");
        }
        if(error == ECONNREFUSED)
        {
            printf( "No one listening on the remote address.\n ");
            return   -1;
        }
    }
    //printf   ( "connected ..3\n ");
    fcntl(socket_num, F_SETFL, savefl);
    
    return 0;
}

