//
//  stun_process_const.h
//  libPusher
//
//  Created by Teng-ChiehKang on 2014/8/14.
//
//

#ifndef libPusher_stun_process_const_h
#define libPusher_stun_process_const_h

typedef enum {
    P2P_NONE =0,
    P2P_ACTIVE_WAITING_RESPONSE,
    P2P_ACTIVE_SENDING_INVITE,
    P2P_ACTIVE_HOLE_PUNCHING,
    P2P_PASSIVE_WAITING_RESPONSE,
    P2P_PASSIVE_HOLE_PUNCHING,
    P2P_SUCCESS,
    P2P_FAIL
} P2PStatus;



//#define PUSHER_API_KEY @"b6ad97ea51c01c300adc"
//#define PUSHER_APP_ID @"81903"
//#define PUSHER_API_SECRET @"7da4eacdc53409262803"

NSString *PUSHER_CHANNEL = @"Monkey";

NSString *PUSHER_EVENT_CHAT= @"chat";
NSString *PUSHER_EVENT_ENTER=@"enter";
NSString *PUSHER_EVENT_LEAVE= @"leave";

NSString *PUSHER_EVENT_P2P_INVITE= @"p2p_invite";
NSString *PUSHER_EVENT_P2P_INVITE_RESPONSE= @"p2p_invite_response";
NSString *PUSHER_EVENT_P2P_CLOSE= @"p2p_close";

NSString *PUSHER_DATA_NAME= @"name";
NSString *PUSHER_DATA_CONTENT= @"content";
NSString *PUSHER_DATA_FROM = @"from";
NSString *PUSHER_DATA_TO = @"to";
NSString *PUSHER_DATA_MAPPEDIP = @"mappedip";
NSString *PUSHER_DATA_MAPPEDPORT = @"mappedport";
NSString *PUSHER_DATA_LOCALIP = @"localip";
NSString *PUSHER_DATA_LOCALPORT = @"localport";
//end of pusher

NSString *KEY_P2PLOCALSOCKET = @"KEY_P2PLOCALSOCKET";
NSString *KEY_P2PSTATUS = @"KEY_P2PSTATUS";
NSString *KEY_P2PTRYCOUNT = @"KEY_P2PTRYCOUNT";
NSString *KEY_P2PSUCCESSCOUNT = @"KEY_P2PSUCCESSCOUNT";
NSString *KEY_MESSAGE = @"KEY_MESSAGE";

NSString *KEY_SELFMAPIP = @"KEY_SELFMAPIP";
NSString *KEY_REMOTEMAPIP = @"KEY_REMOTEMAPIP";
NSString *KEY_REMOTEMAPPORT = @"KEY_REMOTEMAPPORT";

NSString *KEY_REMOTELOCALIP = @"KEY_REMOTELOCALIP";
NSString *KEY_REMOTELOCALPORT = @"KEY_REMOTELOCALPORT";



#endif
