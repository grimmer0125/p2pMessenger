/* $Id$ */
/* 
 * Copyright (C) 2008-2011 Teluu Inc. (http://www.teluu.com)
 * Copyright (C) 2003-2008 Benny Prijono <benny@prijono.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 
 */
#include "stun_hole_puncher.h"
//#include <pjlib-util.h>
//#include <pjlib.h>


#define THIS_FILE	"stun_hole_puncher.c"
//#define LOCAL_PORT	1998
//#define BANDWIDTH	64		    /* -1 to disable */
//#define LIFETIME	600		    /* -1 to disable */
//#define REQ_TRANSPORT	-1		    /* 0: udp, 1: tcp, -1: disable */
//#define REQ_PORT_PROPS	-1		    /* -1 to disable */
//#define REQ_IP		0		    /* IP address string */

////#define OPTIONS		PJ_STUN_NO_AUTHENTICATE
//#define OPTIONS		0

#define BYTE_PUNCHING 1
#define BYTE_PUNCHING_RESPONSE 2

//      8  10  16  Control-Key  Control Action
//NUL	0	0	0	^@          Null character
//SOH	1	1	1	^A          Start of heading, = console interrupt
//STX	2	2	2	^B          Start of text, maintenance mode on HP console
//ETX	3	3	3	^C          End of text
//EOT	4	4	4	^D          End of transmission, not the same as ETB

typedef enum{
    PUNCHING_NOTSTART,
    PUNCHING_ING,
    PUNCHING_SUCCESS,
    PUNCHING_FAIL
} PUNCHING_STATUS;

typedef struct peer
{
    PJ_DECL_LIST_MEMBER(struct peer);
    
    pj_stun_sock   *stun_sock;
    pj_sockaddr	    mapped_addr;
    
    pj_sockaddr remote_target_addr;
    
//  pj_timer_entry *punchingtimer; //為了讓要突然關掉timer時可以做到, 也可以timer找不到peer就不執行, 考慮要不要加
    PUNCHING_STATUS punching_status;
    pj_bool_t got_remote_punching;
    pj_bool_t got_remote_punching_reponses;
    
//    pj_str_t hole_punching_id;
    char *hole_punching_id;
    
    stun_binding_result result_cb;
    stun_receive_data receive_cb;
    stun_punching_result punching_cb;
    
    void *user_data;
}peer;

static struct global
{
    pj_bool_t inited;
    
    pj_caching_pool	 cp;
    pj_pool_t		*pool;
    pj_stun_config	 stun_config;
    pj_thread_t		*thread;
    pj_bool_t		 quit;

//    pj_dns_resolver	*resolver;
//
//    pj_turn_sock	*relay;
//    pj_sockaddr		 relay_addr;

    struct peer plist;
//    struct peer		 peer[2];
} g;

// no use
//static struct options
//{
//    pj_bool_t	 use_tcp;
//    char	*srv_addr;
//    char	*srv_port;
//    char	*realm;
//    char	*user_name;
//    char	*password;
//    pj_bool_t	 use_fingerprint;
//    char	*stun_server;
//    char	*nameserver;
//} o;


static int worker_thread(void *unused);
//static void turn_on_rx_data(pj_turn_sock *relay,
//			    void *pkt,
//			    unsigned pkt_len,
//			    const pj_sockaddr_t *peer_addr,
//			    unsigned addr_len);
//static void turn_on_state(pj_turn_sock *relay, pj_turn_state_t old_state,
//			  pj_turn_state_t new_state);
static pj_bool_t stun_sock_on_status(pj_stun_sock *stun_sock,
				     pj_stun_sock_op op,
				     pj_status_t status);
static pj_bool_t stun_sock_on_rx_data(pj_stun_sock *stun_sock,
				      void *pkt,
				      unsigned pkt_len,
				      const pj_sockaddr_t *src_addr,
				      unsigned addr_len);

static void my_perror(const char *title, pj_status_t status)
{
    char errmsg[PJ_ERR_MSG_SIZE];
    pj_strerror(status, errmsg, sizeof(errmsg));

    PJ_LOG(3,(THIS_FILE, "%s: %s", title, errmsg));
}

#define CHECK(expr)	status=expr; \
			if (status!=PJ_SUCCESS) { \
			    my_perror(#expr, status); \
			    return status; \
			}

static int sock_destory(pj_stun_sock  *stun_sock);

struct peer* find_matched_peerByPeer(struct peer *peer);
struct peer* find_matched_peer(const char* hole_punching_id);

int init(void);
int add_peer_in_list(struct peer *peerlist, struct peer *p2p_peer);

int remove_peer_in_list(struct peer *p2p_peer);


//#define INITPOOLLOCK(x)			(pthread_mutex_init(x, NULL))
//#define DEINITPOOLLOCK(x)		(pthread_mutex_destroy(x))
//#define LOCKPOOL(x) 			(pthread_mutex_lock(x))
//#define UNLOCKPOOL(x)			(pthread_mutex_unlock(x))
//#define TRYLOCKPOOL(x)			(pthread_mutex_trylock(x))

//static pthread_mutex_t mt_mutex = PTHREAD_MUTEX_INITIALIZER;

//#define INITPOOLLOCK(x)			(pthread_mutex_init(x, NULL))
#define DEINITPOOLLOCK(x)		(pj_mutex_destroy(x))
#define LOCKPOOL(x) 			(pj_mutex_lock(x))
#define UNLOCKPOOL(x)			(pj_mutex_unlock(x))
#define TRYLOCKPOOL(x)			(pj_mutex_trylock(x))

pj_mutex_t *mt_mutex;
pj_mutex_t *mt_mutex_plist;
pj_mutex_t *mt_mutex_read;
pj_mutex_t *mt_mutex_write;

//void testCallback(struct peer *pr)
//{
////    pr->cb(pr->holePunchingID,pr->mapped_addr,PJ_SUCCESS);
//}


static void send_puching(struct peer *peer)
{
    pj_sockaddr *remoteAdr = &(peer->remote_target_addr);
    
    char straddr[PJ_INET6_ADDRSTRLEN+10];
    pj_sockaddr_print(remoteAdr, straddr, sizeof(straddr), 3);
    printf("P2P:Send Punching to %s\n",straddr);
    
    char punching_byte = BYTE_PUNCHING;
    
    pj_stun_sock_sendto(peer->stun_sock, NULL, &punching_byte, 1, 0,
                        remoteAdr, pj_sockaddr_get_len(remoteAdr));
}

static void puching_timer_callback(pj_timer_heap_t *ht, pj_timer_entry *e)
{
    if(0 == LOCKPOOL(mt_mutex_write))
    {
        struct peer *peer = (struct peer*)e->user_data;
        
        struct peer *matched_peer = find_matched_peerByPeer(peer);
        
        // find_matched_peerByPeer(peer);
        
        if (matched_peer==NULL) {
            printf("P2P:punching timer is running but invalid_1\n");

            UNLOCKPOOL(mt_mutex_write);
            return;
        }
        
        if (matched_peer->punching_status != PUNCHING_ING) {
            printf("P2P:punching timer is running but invalid_2\n");
            UNLOCKPOOL(mt_mutex_write);
            return;
        }
        
        printf("P2P:punching timer is running_valid\n");

        
        //go head
        
//        char input[32];

//        sprintf(input, "Hello from peer%d", input[0]-'0');

//        pj_sockaddr dst2A;
//        pj_uint16_t port=(pj_uint16_t)12345;
//        pj_str_t ns = pj_str("192.168.11.2");
//        pj_sockaddr_init(pj_AF_INET(), &dst2A, &ns, port);
        
//        pj_sockaddr *remoteAdr = &(matched_peer->remote_target_addr);
//
//        char straddr[PJ_INET6_ADDRSTRLEN+10];
//        
//        pj_sockaddr_print(remoteAdr, straddr, sizeof(straddr), 3);
//        
//        printf("P2P:Send Punching to %s\n",straddr);
//
//        char punching_byte = BYTE_PUNCHING;
//        
//        pj_stun_sock_sendto(peer->stun_sock, NULL, &punching_byte, 1, 0,
//                            remoteAdr, pj_sockaddr_get_len(remoteAdr));

        send_puching(peer);
        
        pj_time_val  delay ;
        delay.sec = 0 ;
        delay.msec = MS_PUNCHING ;
        
        pj_timer_heap_schedule(g.stun_config.timer_heap , e, &delay);
        
        UNLOCKPOOL(mt_mutex_write);
    }
    
    int kkk2 =0;
    
}

    
    
//    struct peer 
//    e->user_data
    
    
//    pj_time_val  delay ;
//    delay.sec = 1 ;
//    delay.msec = 0 ;
//    
//    pj_timer_heap_schedule(ht, e, &delay) ;

//pj_timer_entry   *entry ;

//void test_startTimer()
//{
//    init();
////    pj_timer_heap_t  *timer ;
////    pj_timer_heap_create(g.pool , 1 , &timer ) ;
//
//    
//    
//    //pj_timer_heap_set_max_timed_out_per_poll(this->timer_heap, 20);
////    pj_timer_heap_set_lock(this->timer_heap, this->timer_heap_lock, true);
//  
////    struct pj_timer_entry
////    {
////        void *user_data; // 定时器的用户数据；C++通常用类对象；C通常用struct
////        int id; // 绝对的ID号；用来区分当user_data和cb都相同的情况
////        pj_timer_heap_callback *cb; // 定时器中的回调函数
////    };
//    
//
//    //    pj_timer_entry_init(entry + i, i, &testUserDataA[i], timer_callback);
//
//    pj_timer_entry   *entry = (pj_timer_entry*)pj_pool_calloc(g.pool, 1, sizeof(*entry));
//    entry->cb=&timer_callback;
//    
//    pj_time_val  delay ;
//    delay.sec = 7 ;
//    delay.msec = 0 ;
//    pj_timer_heap_schedule(g.stun_config.timer_heap , entry, &delay);
//}

//void test_stopTimer()
//{
//    pj_timer_heap_cancel(g.stun_config.timer_heap,entry);
//}

//static int init();

int mk_create_sock(const char* hole_punching_id, stun_binding_result cb, stun_receive_data cb2, void *user_data)
{
    pj_status_t status;
    
    if (g.inited==PJ_FALSE) {
        
        status= init();
        g.inited = PJ_TRUE;
        
        if(status !=PJ_SUCCESS)
        {
            return status;
        }
    }
    
//    if(0 == LOCKPOOL(mt_mutex))
//    {
        /*
         * Create peers
         */
        
        //1. create peer
        //2. 把peer, holePunchingID 加入arrray裡
        //3. 設定callback(從server server返回的), 要送給對方, 參數有punchingID跟public ip:port
        
    struct peer *p2p_peer = malloc(sizeof(peer));
    
    p2p_peer->punching_status = PUNCHING_NOTSTART;
    p2p_peer->got_remote_punching=PJ_FALSE;
    p2p_peer->got_remote_punching_reponses=PJ_FALSE;
    
    pj_stun_sock_cb stun_sock_cb;
    //char name[] = "peer0";
    pj_uint16_t port;
    pj_stun_sock_cfg ss_cfg;
    pj_str_t server;
    
    pj_bzero(&stun_sock_cb, sizeof(stun_sock_cb));
    stun_sock_cb.on_rx_data = &stun_sock_on_rx_data;
    stun_sock_cb.on_status = &stun_sock_on_status;
    
    p2p_peer->mapped_addr.addr.sa_family = pj_AF_INET();
    //    g.peer[i].mapped_addr.addr.sa_family = pj_AF_INET();
    
    pj_stun_sock_cfg_default(&ss_cfg);
#if 1
    /* make reading the log easier */
    ss_cfg.ka_interval = 300;
#endif
    
    //    name[strlen(name)-1] = '0'+i;
    status = pj_stun_sock_create(&g.stun_config, NULL, pj_AF_INET(),
                                 &stun_sock_cb, &ss_cfg,
                                 p2p_peer, &p2p_peer->stun_sock);
    if (status != PJ_SUCCESS) {
        my_perror("pj_stun_sock_create()", status);
//        UNLOCKPOOL(mt_mutex);
        return status;
    }
    
    //        if (o.stun_server) {
    server = pj_str(STUN_SERVER);
    port = PJ_STUN_PORT;
    //        } else {
    //            server = pj_str(o.srv_addr);
    //            port = (pj_uint16_t)(o.srv_port?atoi(o.srv_port):PJ_STUN_PORT);
    //        }
    status = pj_stun_sock_start(p2p_peer->stun_sock, &server,
                                port,  NULL);
    if (status != PJ_SUCCESS) {
        my_perror("pj_stun_sock_start()", status);
//        UNLOCKPOOL(mt_mutex);
        return status;
    }
    
    //    pj_str_t holeID = pj_str(holePunchingID);
    p2p_peer->hole_punching_id =  //pj_str((char*)hole_punching_id);
    strdup(hole_punching_id);
    
//        printf("P2P:hole2:%.*s\n", (int)p2p_peer->hole_punching_id.slen , p2p_peer->hole_punching_id.ptr);
    
//        const char *test = pj_strbuf(&p2p_peer->hole_punching_id);
    printf("P2P:hole punching(by strdup):%s\n",p2p_peer->hole_punching_id);
    

    p2p_peer->result_cb = cb;
    p2p_peer->receive_cb =cb2;
    p2p_peer->user_data = user_data;
    
    add_peer_in_list(&g.plist, p2p_peer);
    
//        struct peer *matched_peer = find_matched_peer(hole_punching_id);
    
    
//    UNLOCKPOOL(mt_mutex);
//    }
    
    return PJ_SUCCESS;
}

int init()
{

//    printf("stun_test_init");

//    o.stun_server = "stun.counterpath.com";//pj_optarg;

//    int i;
    pj_status_t status;

    CHECK( pj_init() );
    CHECK( pjlib_util_init() );
    CHECK( pjnath_init() );

    /* Check that server is specified */
//    if (!o.srv_addr) {
//	printf("Error: server must be specified\n");
//	return PJ_EINVAL;
//    }

    pj_caching_pool_init(&g.cp, &pj_pool_factory_default_policy, 0);

    g.pool = pj_pool_create(&g.cp.factory, "main", 1000, 1000, NULL);

    /* Init global STUN config */
    pj_stun_config_init(&g.stun_config, &g.cp.factory, 0, NULL, NULL);

    /* Create global timer heap */
    CHECK( pj_timer_heap_create(g.pool, 1000, &g.stun_config.timer_heap) );

    /* Create global ioqueue */
    CHECK( pj_ioqueue_create(g.pool, 16, &g.stun_config.ioqueue) );
    
    /* Start the worker thread */
    CHECK( pj_thread_create(g.pool, "stun", &worker_thread, NULL, 0, 0, &g.thread) );
    
    pj_list_init(&g.plist);
    
    pj_mutex_create(g.pool, "", PJ_MUTEX_SIMPLE, &mt_mutex);
    
    pj_mutex_create(g.pool, "", PJ_MUTEX_SIMPLE, &mt_mutex_plist);
    pj_mutex_create(g.pool, "", PJ_MUTEX_SIMPLE, &mt_mutex_read);
    pj_mutex_create(g.pool, "", PJ_MUTEX_SIMPLE, &mt_mutex_write);

    
    return PJ_SUCCESS;
}

int add_peer_in_list(struct peer *peerlist, struct peer *p2p_peer)
{
    if(0 == LOCKPOOL(mt_mutex_plist))
    {
        pj_list_insert_before(peerlist, p2p_peer);

        UNLOCKPOOL(mt_mutex_plist);
    }
    
    return PJ_SUCCESS;
}

int remove_peer_in_list(struct peer *p2p_peer)
{
    if(0 == LOCKPOOL(mt_mutex_plist))
    {
        pj_list_erase(p2p_peer);

//        pj_list_insert_before(peerlist, p2p_peer);
        
        UNLOCKPOOL(mt_mutex_plist);
    }
    
    return PJ_SUCCESS;
}

struct peer* find_matched_peerByPeer(struct peer *peer)
{
    struct peer *loop_peer;
    struct peer *matched_peer = NULL;
    
    if(0 == LOCKPOOL(mt_mutex_plist))
    {
    
        loop_peer = g.plist.next;
        while (loop_peer != &g.plist)
        {
            if (loop_peer==peer) {
                matched_peer =loop_peer;
                break;
            }
            
            loop_peer = loop_peer->next;
        }
        
        UNLOCKPOOL(mt_mutex_plist);
    }
    
    return matched_peer;
}

struct peer* find_matched_peer(const char* hole_punching_id)
{
    struct peer *loop_peer;
    struct peer *matched_peer = NULL;
    
    if(0 == LOCKPOOL(mt_mutex_plist))
    {
        loop_peer = g.plist.next;
        while (loop_peer != &g.plist)
        {
    //        printf("%s vs %s",loop_peer->hole_punching_id,hole_punching_id);
    //        printf("size:%lu;%lu",strlen(loop_peer->hole_punching_id),strlen(hole_punching_id));
            if (strcmp(loop_peer->hole_punching_id, hole_punching_id)==0)//pj_strcmp2(&loop_peer->hole_punching_id,hole_punching_id)==0)
            {
                matched_peer = loop_peer;
                break;
            }
            
            loop_peer = loop_peer->next;
        }
        
        UNLOCKPOOL(mt_mutex_plist);
    
//    if (matched_peer==NULL) {
//        return NULL;
//    }
    
//    if (matched_peer==NULL) {
//        int kk=0;
//    }
        
        
    }
    
    return matched_peer;
}

int mk_start_hole_punching(const char* hole_punching_id,  const char *remote_mapped_ip, int remote_mapped_port, const char *remote_local_ip, int remote_local_port,  stun_punching_result cb1, void *user_data)
{
    if(g.inited && 0 == LOCKPOOL(mt_mutex_write))
    {
//        struct peer *loop_peer;
        //若不清掉上一次的可能這次取到之前的 !!!
        struct peer *matched_peer = find_matched_peer(hole_punching_id);
//        
//        loop_peer = g.plist.next;
//        while (loop_peer != &g.plist)
//        {
//            if (pj_strcmp2(&loop_peer->hole_punching_id,hole_punching_id)==0)
//            {
//                matched_peer = loop_peer;
//                break;
//            }
//            
//            loop_peer = loop_peer->next;
//        }
        
        if (matched_peer==NULL) {
            UNLOCKPOOL(mt_mutex_write);
            return PJ_SUCCESS;
        }
        
        matched_peer->punching_status = PUNCHING_ING;
        matched_peer->punching_cb=cb1;
        
        pj_str_t remote_mapped_ip_str = pj_str((char*)remote_mapped_ip);
        
        char *self_ip = pj_inet_ntoa(matched_peer->mapped_addr.ipv4.sin_addr);
        pj_str_t self_map_ip = pj_str(self_ip);
        
        if (pj_strcmp(&remote_mapped_ip_str, &self_map_ip)==0)
        {
            printf("P2P:Start hole punching, Lan\n");
            //the same lan

            pj_sockaddr dst;
            pj_str_t ns = pj_str((char*)remote_local_ip);
            pj_uint16_t port=(pj_uint16_t)remote_local_port;
            pj_sockaddr_init(pj_AF_INET(), &dst, &ns, port);
            
            
//            if (dst.addr.sa_family == PJ_AF_INET) {
//                int kkk = 0;
//            }
//            
//            if (dst.addr.sa_family == PJ_AF_INET6) {
//                int kkk=0;
//            }
//            
//            
//            printf("dst fam:%d\n",dst.addr.sa_family);
            
//            p2p_peer->mapped_addr.addr.sa_family = pj_AF_INET();

            
//            char str1[PJ_INET6_ADDRSTRLEN+10];
//            pj_sockaddr_print(&dst, str1, sizeof(str1), 3);
//            
//            printf("dst:%s\n",str1);
            
            matched_peer->remote_target_addr = dst;
            
            
//            if (matched_peer->remote_target_addr.addr.sa_family == PJ_AF_INET) {
//                int kkk = 0;
//            }
//            
//            if (matched_peer->remote_target_addr.addr.sa_family == PJ_AF_INET6) {
//                int kkk=0;
//            }
//            
//            
//            printf("remote dst fam:%d\n",matched_peer->remote_target_addr.addr.sa_family);
//            
//            char str2[PJ_INET6_ADDRSTRLEN+10];
//            pj_sockaddr_print(&(matched_peer->remote_target_addr), str2, sizeof(str2), 3);
//            
//            printf("remote dst:%s\n",str2);
            
            
            
//            pj_stun_sock_sendto(peer->stun_sock, NULL, input, strlen(input)+1, 0,
//                                &dst2A, pj_sockaddr_get_len(&dst2A));
        }
        else
        {
            //use map_adr
            
            printf("P2P:Start hole punching, Wan\n");

            pj_sockaddr dst;
//            pj_str_t ns = pj_str((char*)remote_local_ip);
            pj_uint16_t port=(pj_uint16_t)remote_mapped_port;;
            pj_sockaddr_init(pj_AF_INET(), &dst, &remote_mapped_ip_str, port);
            
            matched_peer->remote_target_addr = dst;
            
        }
        
        pj_timer_entry  *entry = (pj_timer_entry*)pj_pool_calloc(g.pool, 1, sizeof(*entry));
        entry->cb=&puching_timer_callback;
        
        entry->user_data = matched_peer;
        
        pj_time_val  delay ;
        delay.sec = 0 ;
        delay.msec = MS_PUNCHING ;
        
        send_puching(matched_peer);
        
        pj_timer_heap_schedule(g.stun_config.timer_heap , entry, &delay);
        
        UNLOCKPOOL(mt_mutex_write);

        
        //            0. 開始timer發punching包, 裡面要寫
        //                a. 送的人是誰(對方要寫自己來找出punchingID)
        //                b. 要檢查對方的ip跟這次的punching是不是同一個嗎?  先不用
        //
        //            1. 開始收data
        //                a. 若收到punching的代表收到別人的, 傳response回去, 要嘛sock可以找出送的人addr, 要嘛寫在punching包裡.
        //                b. 要收到對方的punching包 且收到別人的response 才算成功. (這兩個順序不一定)
    }
    
    //                int kk =sizeof(straddr_selfaddr);
    //                pj_sockaddr_print(&info.mapped_addr, straddr2, sizeof(straddr2), 3);
    //                pj_sockaddr_print(&info.bound_addr, straddr3, sizeof(straddr3), 3);
    
    //                if (info.alias_cnt>0) {
    //                    pj_sockaddr_print(&info.aliases[0], straddr_selfaddr, sizeof(straddr_selfaddr), 3);
    //
    //                    int kkk=0;
    //                }
//    getselfaddr(&info, straddr_selfaddr,PJ_INET6_ADDRSTRLEN+10 );
    
    return 0;
}

int mk_sendata(const char* hole_punching_id, const char *data, int datalen)
{    
    if(g.inited && 0 == LOCKPOOL(mt_mutex_write))
    {
        printf("P2P:Send data\n");

        struct peer *matched_peer = find_matched_peer(hole_punching_id);
        
        pj_sockaddr *remoteAdr = &(matched_peer->remote_target_addr);
        
        pj_stun_sock_sendto(matched_peer->stun_sock, NULL, data, datalen, 0,
                            remoteAdr, pj_sockaddr_get_len(remoteAdr));
        
        UNLOCKPOOL(mt_mutex_write);
    }
    
    return 0;
}

int mk_close_sock(const char* hole_punching_id)
{
    if(g.inited)
    {
        if(0 == LOCKPOOL(mt_mutex_read))
        {
            if (0==LOCKPOOL(mt_mutex_write))
            {
                
            
    //        struct peer *loop_peer;
                struct peer *matched_peer = find_matched_peer(hole_punching_id);
                
        //        loop_peer = g.plist.next;
        //        while (loop_peer != &g.plist)
        //        {
        //            if (pj_strcmp2(&loop_peer->hole_punching_id,hole_punching_id)==0)
        //            {
        //                matched_peer = loop_peer;
        //                break;
        //            }
        //            
        //            loop_peer = loop_peer->next;
        //        }
                
                if (matched_peer==NULL) {
                    UNLOCKPOOL(mt_mutex_write);
                    UNLOCKPOOL(mt_mutex_read);
                    return PJ_SUCCESS;
                }
                
                matched_peer->punching_status=PUNCHING_FAIL;
                
                
                sock_destory(matched_peer->stun_sock);
                
                free(matched_peer->hole_punching_id);
                
                remove_peer_in_list(matched_peer);
        //        pj_list_erase(matched_peer);
                
                free(matched_peer);
                
                UNLOCKPOOL(mt_mutex_write);
            }
            
            UNLOCKPOOL(mt_mutex_read);
        }
    }
    
    return PJ_SUCCESS;
}

static int sock_destory(pj_stun_sock  *stun_sock)
{
    if (stun_sock)
    {
        pj_stun_sock_destroy(stun_sock);
    }
    
    return PJ_SUCCESS;
}


static int client_shutdown()
{
    printf("client shutdown1");
//    unsigned i;

    if (g.thread) {
        g.quit = 1;
        pj_thread_join(g.thread);
        pj_thread_destroy(g.thread);
        g.thread = NULL;
    }
    
//    if (g.relay) {
//        pj_turn_sock_destroy(g.relay);
//        g.relay = NULL;
//    }
    
    if (g.stun_config.timer_heap)
    {
        pj_timer_heap_destroy(g.stun_config.timer_heap);
        g.stun_config.timer_heap = NULL;
    }
    
    if (g.stun_config.ioqueue) {
        pj_ioqueue_destroy(g.stun_config.ioqueue);
        g.stun_config.ioqueue = NULL;
    }
    
    if (g.pool)
    {
        pj_pool_release(g.pool);
        g.pool = NULL;
    }
    
    
    DEINITPOOLLOCK(mt_mutex);

    DEINITPOOLLOCK(mt_mutex_plist);

    DEINITPOOLLOCK(mt_mutex_read);

    DEINITPOOLLOCK(mt_mutex_write);


    pj_pool_factory_dump(&g.cp.factory, PJ_TRUE);
    pj_caching_pool_destroy(&g.cp);
    
    
    return PJ_SUCCESS;
}


static int worker_thread(void *unused)
{
    PJ_UNUSED_ARG(unused);
    
    while (!g.quit)
    {
        const pj_time_val delay = {0, 10};

        /* Poll ioqueue for the TURN client */
        pj_ioqueue_poll(g.stun_config.ioqueue, &delay);

        /* Poll the timer heap */
        pj_timer_heap_poll(g.stun_config.timer_heap, NULL);
    }
    
    return 0;
}

static void getselfaddr(pj_stun_sock_info *info, char* straddr_selfaddr, int size)
{
    if ((*info).alias_cnt>0)
    {
//        int kk =sizeof(straddr_selfaddr);

        pj_sockaddr_print(&(*info).aliases[0], straddr_selfaddr, size, 3);
    }
}

static pj_bool_t stun_sock_on_status(pj_stun_sock *stun_sock,
				     pj_stun_sock_op op,
				     pj_status_t status)
{
    if(0 == LOCKPOOL(mt_mutex_read))
    {
        struct peer *peer = (struct peer*) pj_stun_sock_get_user_data(stun_sock);

        if (peer==NULL) {
            
            UNLOCKPOOL(mt_mutex_read);
            
            return PJ_FALSE;
        }
        
//        struct peer *loop_peer;
        
        struct peer *matched_peer = find_matched_peerByPeer(peer);
//
//        loop_peer = g.plist.next;
//        while (loop_peer != &g.plist)
//        {
//            if (peer==loop_peer) {
//                matched_peer =loop_peer;
//                break;
//            }
//            
//            loop_peer = loop_peer->next;
//        }
        
        if (matched_peer==NULL) {
            
            UNLOCKPOOL(mt_mutex_read);

            return PJ_FALSE;
        }
        
        if (status == PJ_SUCCESS) {
//            printf("peer:%.*s;", (int)matched_peer->hole_punching_id.slen , matched_peer->hole_punching_id.ptr);
            
            printf("peer:%s",matched_peer->hole_punching_id);
            
            PJ_LOG(4,(THIS_FILE, "%s success",
                  pj_stun_sock_op_name(op)));
        } else {
            char errmsg[PJ_ERR_MSG_SIZE];
            pj_strerror(status, errmsg, sizeof(errmsg));
            PJ_LOG(1,(THIS_FILE, "%s error: %s",
                  pj_stun_sock_op_name(op), errmsg));
            
            matched_peer->result_cb(matched_peer->hole_punching_id,
                                    NULL,NULL,
                                    PJ_FALSE,matched_peer->user_data);
            
            UNLOCKPOOL(mt_mutex_read);

            return PJ_FALSE;
        }

        if (op==PJ_STUN_SOCK_BINDING_OP || op==PJ_STUN_SOCK_KEEP_ALIVE_OP) {
            
            if (op==PJ_STUN_SOCK_KEEP_ALIVE_OP) {
                printf("got stun keepAive packet");
            }
            
            pj_stun_sock_info info;

            int cmp;

            pj_stun_sock_get_info(stun_sock, &info);
            cmp = pj_sockaddr_cmp(&info.mapped_addr, &peer->mapped_addr);

            if (cmp) {
                char straddr[PJ_INET6_ADDRSTRLEN+10];

//                char straddr2[PJ_INET6_ADDRSTRLEN+10];
//
//                char straddr3[PJ_INET6_ADDRSTRLEN+10];
                
                char straddr_selfaddr[PJ_INET6_ADDRSTRLEN+10];
                getselfaddr(&info, straddr_selfaddr,PJ_INET6_ADDRSTRLEN+10 );
//                matched_peer->local_addr.addr.sa_family =pj_AF_INET();
//                pj_sockaddr_cp(&matched_peer->local_addr, &info.aliases[0]);

                
                pj_sockaddr_cp(&peer->mapped_addr, &info.mapped_addr);
                pj_sockaddr_print(&peer->mapped_addr, straddr, sizeof(straddr), 3);
                PJ_LOG(3,(THIS_FILE, "STUN mapped address is %s"
                          , straddr));
                
//                pj_str_t addrStr = pj_str(straddr);                
//                pj_str_t target = pj_str(":");
//                char *find2 = pj_strstr(&addrStr, &target);
//                char *ipp2 =   pj_inet_ntoa(peer->mapped_addr.ipv6 sin6_addr);

                
                matched_peer->result_cb(matched_peer->hole_punching_id,
                                        straddr,
                                        straddr_selfaddr,
                                        PJ_SUCCESS, matched_peer->user_data);
            }
        }
     
        UNLOCKPOOL(mt_mutex_read);
    }

    return PJ_TRUE;
}

static pj_bool_t stun_sock_on_rx_data(pj_stun_sock *stun_sock,
				      void *pkt,
				      unsigned pkt_len,
				      const pj_sockaddr_t *src_addr,
				      unsigned addr_len)
{
    if(0 == LOCKPOOL(mt_mutex_read))
    {
        struct peer *peer = (struct peer*) pj_stun_sock_get_user_data(stun_sock);
        
        if (peer==NULL) {
            UNLOCKPOOL(mt_mutex_read);
            return PJ_FALSE;
        }
        
        struct peer *matched_peer = find_matched_peerByPeer(peer);
        
        if (matched_peer==NULL) {
            UNLOCKPOOL(mt_mutex_read);
            return PJ_FALSE;
        }
        
        pj_bool_t pre_both_OK = matched_peer->got_remote_punching && matched_peer->got_remote_punching_reponses;
        
        if (pkt_len==1)
        {
            char *only_byte= (char*)pkt;
            if (*only_byte==BYTE_PUNCHING)
            {
                printf("P2P:Get punching\n");

                //缺點是這邊認為punching成功後, 對方只發1個byte=BYTE_PUNCHING_RESPONSE,
                //還是只能代表punching的意思,
                //
                //這邊認為成功後還是要回這個是怕對方沒有收到punching response
                
                //got punching 包
                matched_peer->got_remote_punching=PJ_TRUE;
                
                //send back
                char punching_byte = BYTE_PUNCHING_RESPONSE;
                
                
//                pj_sockaddr *remoteAdr = &(matched_peer->remote_target_addr);

//                if (matched_peer->remote_target_addr.addr.sa_family == PJ_AF_INET) {
//                    int kkk = 0;
//                    printf("crash1\n");
//                }
//                
//                if (matched_peer->remote_target_addr.addr.sa_family == PJ_AF_INET6) {
//                    int kkk=0;
//                    printf("crash2\n");
//                }
//                
//                printf("dst fam:%d\n",matched_peer->remote_target_addr.addr.sa_family);
//                
//                char str1[PJ_INET6_ADDRSTRLEN+10];
//                pj_sockaddr_print(&(matched_peer->remote_target_addr), str1, sizeof(str1), 3);
//                
//                printf("dst:%s\n",str1);
//                
                
                pj_stun_sock_sendto(peer->stun_sock, NULL, &punching_byte, 1, 0,
                                    src_addr, pj_sockaddr_get_len(src_addr));
            }
            else if (*only_byte==BYTE_PUNCHING_RESPONSE)
            {
                printf("P2P:Get punching response\n");

                if (pre_both_OK==PJ_FALSE) {
                    matched_peer->got_remote_punching_reponses=PJ_TRUE;
                }
                else
                {
                    //至少punching成功後, 對方可以只發1個byte=BYTE_PUNCHING_RESPONSE for其他意思的
                    matched_peer->receive_cb(matched_peer->hole_punching_id,pkt,pkt_len,matched_peer->user_data);
                }
            }
            else
            {
                printf("P2P:Get other\n");

                if (matched_peer->got_remote_punching && pre_both_OK==PJ_FALSE) {
                    
                    //如果剛好對方送的response lost掉, 第一個任何其他 包也算
                    
                    // OK
                    matched_peer->got_remote_punching_reponses=PJ_TRUE;
                    matched_peer->punching_status = PUNCHING_SUCCESS;
                    
    //                stun_punching_result
                    matched_peer->punching_cb(matched_peer->hole_punching_id,
                                              PJ_SUCCESS,matched_peer->user_data);
                    
                    pre_both_OK= PJ_TRUE;

                    
                }
                
                //receive data
                matched_peer->receive_cb(matched_peer->hole_punching_id,pkt,pkt_len,matched_peer->user_data);
            }
        }
        else
        {
            printf("P2P:Get others\n");

            //如果剛好對方送的response lost掉, 第一個任何其他 包也算
            if (matched_peer->got_remote_punching && pre_both_OK==PJ_FALSE) {
                
                // OK
                matched_peer->got_remote_punching_reponses=PJ_TRUE;
                matched_peer->punching_status = PUNCHING_SUCCESS;
                
                matched_peer->punching_cb(matched_peer->hole_punching_id,
                                          PJ_SUCCESS,matched_peer->user_data);
                
                pre_both_OK= PJ_TRUE;
            }
            
            //receive data
            
            matched_peer->receive_cb(matched_peer->hole_punching_id,pkt,pkt_len,matched_peer->user_data);
        }
        
        if (pre_both_OK==PJ_FALSE &&
            matched_peer->got_remote_punching &&
            matched_peer->got_remote_punching_reponses)
        {
            //punching OK
            matched_peer->punching_status = PUNCHING_SUCCESS;
            matched_peer->punching_cb(matched_peer->hole_punching_id,
                                      PJ_SUCCESS,matched_peer->user_data);
            
    //        matched_peer->result_cb(pj_strbuf(&matched_peer->hole_punching_id),
    //                                straddr,
    //                                straddr_selfaddr,
    //                                PJ_SUCCESS, matched_peer->user_data);
            
        }
        
        UNLOCKPOOL(mt_mutex_read);

    }

    return PJ_TRUE;

//    char straddr[PJ_INET6_ADDRSTRLEN+10];
//
//    ((char*)pkt)[pkt_len] = '\0';
//
//    pj_sockaddr_print(src_addr, straddr, sizeof(straddr), 3);
//    
//    //print punchingID
//    PJ_LOG(3,(THIS_FILE, "received %d bytes data from %s: %s",
//	       pkt_len, straddr, (char*)pkt));
//
//    return PJ_TRUE;
    
}