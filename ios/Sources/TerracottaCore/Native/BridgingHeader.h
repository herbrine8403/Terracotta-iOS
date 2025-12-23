//
//  BridgingHeader.h
//  TerracottaCore
//
//  Created for Terracotta iOS adaptation
//

#ifndef BridgingHeader_h
#define BridgingHeader_h

#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>
#import <SystemConfiguration/SystemConfiguration.h>

// ZeroTier C API
#import "terracotta.h"

// MARK: - Native Functions

#ifdef __cplusplus
extern "C" {
#endif

// ZeroTier Node Management
bool terracotta_start_node(const char *node_id);
void terracotta_stop_node(void);
bool terracotta_join_network(const char *network_id);
bool terracotta_leave_network(const char *network_id);
const char *terracotta_get_node_status(void);

// Room Management
bool terracotta_create_room(const char *room_code, const char *player_name);
bool terracotta_join_room(const char *room_code, const char *player_name);
void terracotta_leave_room(void);
const char *terracotta_get_room_status(void);

// State Management
const char *terracotta_get_state(void);
void terracotta_set_waiting_state(void);
void terracotta_set_scanning_state(const char *room_code, const char *player_name);
void terracotta_set_hosting_state(const char *room_code, const char *player_name);
void terracotta_set_guesting_state(const char *room_code, const char *player_name);

// Utility Functions
void terracotta_init_logging(const char *log_path);
const char *terracotta_get_version(void);
const char *terracotta_get_error_message(void);

// Callback Functions
typedef void (*TerracottaStateCallback)(const char *state);
typedef void (*TerracottaErrorCallback)(const char *error);
typedef void (*TerracottaLogCallback)(const char *log_message);

void terracotta_set_state_callback(TerracottaStateCallback callback);
void terracotta_set_error_callback(TerracottaErrorCallback callback);
void terracotta_set_log_callback(TerracottaLogCallback callback);

#ifdef __cplusplus
}
#endif

#endif /* BridgingHeader_h */