/*******************************************************************
 
 File name: OCSocketManage
 
 Description:
 1、处理所有的应用层数据交互。
 
 Author: Mako
 
 History: 2014.5.22。
 
 *******************************************************************/

#import <Foundation/Foundation.h>

#include "OCSocket.h"

#define OCSocketManageReadAndCheckEnd OCSocketManageReadData(2)

//是否做自动连接
#ifdef OCSM_AutoReconnect
//登陆前连接
#define OCSocketManageAutoReconnectBeforeLogin if(OCSocketManageTestConnect() != YES){\
OCSM_Error smErr = OCSocketManageMasterServerConnect();\
if(smErr != SM_Success)\
return smErr;\
}

//登陆后连接
#define OCSocketManageAutoReconnectAfterLogin OCSM_Error connectErr = OCSocketManageReconnectLogin();\
if(connectErr != SM_Success)\
return connectErr;

#else

//登陆前连接
#define OCSocketManageAutoReconnectBeforeLogin
//登陆后连接
#define OCSocketManageAutoReconnectAfterLogin


#endif

typedef NS_ENUM(NSInteger, OCSM_Error)
{
    SM_Success           = 0,           //成功
    SM_WriteFail         = 1,           //写入数据失败，会导致关闭socket连接
    SM_NoData            = 2,           //无数据，可能原因：被后台掉、超时未返回
    //连接
    SM_NoNetwork         = 3,           //没有网络
    SM_ConnectFail       = 4,           //连接失败
    SM_LoginError        = 5,           //登录失败
    SM_GetIPerror        = 6,           //获取IP地址失败
    SM_commandMarkError  = 7,           //标记命令错误
    SM_ReadFail          = 8,           //读取失败
    SM_serverClose       = 9,           //服务器端关闭
    SM_ShakeHandsFail    =10,           //握手失败
    SM_GetDeviceTokenFail=11,           //获取设备令牌失败
    SM_UserDelete        =12            //用户被删除
};

struct OCSocketManage
{
    OCSocket *socketCom;
    pthread_mutex_t socketMutex;
    pthread_cond_t socketCond;
    struct timespec waitTime;
    //网络参数
    char *connectIPAddress;
    int connectPort;
    int connectTimeOut;
    int receiveTimeOut;
    //命令标记
    char commandMark[4];
    //收到的数据
    __unsafe_unretained NSMutableData *bufferMData;
    //control
    BOOL isRequestClose;    //请求关闭
    //结果数据
    __unsafe_unretained id resultObject;
};

typedef struct OCSocketManage OCSocketManage;

#pragma mark 基本函数
//获取单例
OCSocketManage *getSocketManage(void);

//连接
OCSM_Error OCSocketManageConnect(void);

//测试并重连
OCSM_Error OCSocketManageReconnectLogin(void);

//关闭连接
void OCSocketManageCloseConnect(void);


#pragma mark 数据处理
//获取命令标记（可修改其实现）
void OCSocketManageSetCommandMark(void);

//从缓存中读取数据
NSData *OCSocketManageReadData(NSUInteger readLength);

//自动读取缓存中的数据
NSString *OCSocketManageAutoReadString(void);

//判断命令标记，并赋值，唤醒主线程
BOOL OCSocketManageCompareCmdMarkAndAwakenSendThread(const char *rcvCmdMark,id resultObj);

//从缓存中读取给定长度的数据，并转化为字符串
NSString *OCSocketManageReadString(int strLen);

//从NSMutableData中读取数据，读出的数据将会被删除
NSData *readFromMutableData(NSMutableData **mDataPointer, NSUInteger readLength);

//从NSMutableData中读取字符串
NSString *readStringFromMutableData(NSMutableData **mDataPointer, NSUInteger readLength);

//主服务器返回的特殊验证
BOOL OCSocketManageCompareSeverAndAwakenSendThread(const char *rcvCmdMark,id resultObj);

#pragma mark 发送处理
//2.23添加，完成发送线程的发送数据并等待唤醒的工作
OCSM_Error OCSocketManageSendDataAndWaitResult(OCSocketManage *socketManage, NSData *data, id *rstObj);

#pragma mark -
#pragma mark 返回数据解析




