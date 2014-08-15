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
#ifndef stun_hole_puncher_h
#define stun_hole_puncher_h


#include <pjlib.h>
#include <pjlib-util.h>
#include <pjnath.h>

#define STUN_SERVER "stun.counterpath.com"


//#define INCLUDE_STUN_TEST	    1
//#define INCLUDE_ICE_TEST	    1
//#define INCLUDE_STUN_SOCK_TEST	    1
//#define INCLUDE_TURN_SOCK_TEST	    1
//#define INCLUDE_CONCUR_TEST    	    1

//int initK();
//int stun_test_init();
//void closeSock(pj_stun_sock *sock);

typedef void (*stun_binding_result)(const char* hole_punching_id,
                               char *mapp_addr,
                               char *local_addr,
                               pj_status_t status,
                               void *user_data);

typedef void (*stun_punching_result)(const char* hole_punching_id,
                            pj_status_t status,
                            void *user_data);

typedef void (*stun_receive_data)(const char* hole_punching_id,
                         unsigned char *data,
                         int datalen,
                        void *user_data);


int mk_create_sock(const char* hole_punching_id, stun_binding_result cb, stun_receive_data cb2,void *user_data);
int mk_close_sock(const char* hole_punching_id);

int mk_start_hole_punching(const char* hole_punching_id,  const char *remote_mapped_ip, int remote_mapped_port, const char *remote_local_ip, int remote_local_port,  stun_punching_result cb, void *user_data);

int mk_sendata(const char* hole_punching_id, const char *data, int datalen);

//void test_startTimer();
//void test_stopTimer();
//void registerCallback(on_status cb);
//void testCallback(struct peer *pr);

//int stun_test(void);
//int sess_auth_test(void);
//int stun_sock_test(void);
//int turn_sock_test(void);
//int ice_test(void);
//int concur_test(void);
//int test_main(void);
//
//extern void app_perror(const char *title, pj_status_t rc);
//extern pj_pool_factory *mem;

//int ice_one_conc_test(pj_stun_config *stun_cfg, int err_quit);
//
//////////////////////////////////////
///*
// * Utilities
// */
//pj_status_t create_stun_config(pj_pool_t *pool, pj_stun_config *stun_cfg);
//void destroy_stun_config(pj_stun_config *stun_cfg);
//
//void poll_events(pj_stun_config *stun_cfg, unsigned msec,
//		 pj_bool_t first_event_only);
//
//typedef struct pjlib_state
//{
//    unsigned	timer_cnt;	/* Number of timer entries */
//    unsigned	pool_used_cnt;	/* Number of app pools	    */
//} pjlib_state;
//
//
//void capture_pjlib_state(pj_stun_config *cfg, struct pjlib_state *st);
//int check_pjlib_state(pj_stun_config *cfg, 
//		      const struct pjlib_state *initial_st);
//
//
//#define ERR_MEMORY_LEAK	    1
//#define ERR_TIMER_LEAK	    2
#endif
