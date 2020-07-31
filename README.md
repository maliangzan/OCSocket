# OCSocket
智能家居socket
调用方法很简单：
~~~ OCSocketManage *socketManange = getSocketManage();
    OCSM_Error error = OCSocketManageSendDataAndWaitResult(socketManange, nil, &resultDic);
    if (error == SM_Success){
        NSLog(@"%@",resultDic);
    }else{
        switch (error) {
            case SM_LoginError:
               
                break;
            case SM_NoNetwork:
               
                break;
            case SM_UserDelete:
               
                break;
            default:
                
                break;
        }
    }
    
    引用 pod 'OCSocket'
    
    功能主要是使用socket实现智能家居中控制设备执行命令，并且实现长连接的推送。
