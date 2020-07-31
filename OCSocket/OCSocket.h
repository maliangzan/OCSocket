/*******************************************************************
 
 File name: OCSocket
 
 Description:
 1、socket基本通信。
 
 Author: Mako
 
 History: 2010.7.31。
 
 *******************************************************************/

#ifndef OCSocket_h
#define OCSocket_h

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <pthread.h>
#include <netdb.h>
#include <sys/time.h>


typedef enum
{
    readError,    //读取错误
    serverClose,    //服务器端关闭
}CancelCode;

struct OCSocket;

typedef struct OCSocket OCSocket;

typedef void (*socketReceiveDataCallback)(void *delegate, OCSocket *selfSocket, NSData *rcvData);

typedef void (*socketDidCanceledCallBack)(void *delegate, OCSocket *selfSocket, CancelCode cancelRst);


//初始化函数，返回NULL表示连接失败
OCSocket *OCSocketCreateWithInformation(const char *hostIPStr, short port, int time, void *theDelegate, socketReceiveDataCallback receiveCB, socketDidCanceledCallBack canceledCB);

//写入数据
BOOL OCSocketWriteData(OCSocket *selfSocket, NSData *data);

//关闭连接
void OCSocketClostConnect(OCSocket *selfSocket);

NSString *getIPAddressForHost(NSString *theHost);

#endif

