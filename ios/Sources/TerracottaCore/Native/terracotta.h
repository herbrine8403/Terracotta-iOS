//
//  terracotta.h
//  TerracottaCore
//
//  Native C interface for Terracotta iOS adaptation
//

#ifndef terracotta_h
#define terracotta_h

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// MARK: - Constants

#define TERRACOTTA_MAX_NETWORK_ID_LEN 64
#define TERRACOTTA_MAX_NODE_ID_LEN 32
#define TERRACOTTA_MAX_ROOM_CODE_LEN 64
#define TERRACOTTA_MAX_PLAYER_NAME_LEN 32
#define TERRACOTTA_MAX_ERROR_MESSAGE_LEN 256
#define TERRACOTTA_MAX_LOG_MESSAGE_LEN 512

// MARK: - Enums

typedef enum {
    TERRACOTTA_STATE_WAITING = 0,
    TERRACOTTA_STATE_HOST_SCANNING = 1,
    TERRACOTTA_STATE_HOST_STARTING = 2,
    TERRACOTTA_STATE_HOST_OK = 3,
    TERRACOTTA_STATE_GUEST_CONNECTING = 4,
    TERRACOTTA_STATE_GUEST_STARTING = 5,
    TERRACOTTA_STATE_GUEST_OK = 6,
    TERRACOTTA_STATE_EXCEPTION = 7
} terracotta_state_t;

typedef enum {
    TERRACOTTA_ERROR_NONE = 0,
    TERRACOTTA_ERROR_NODE_START_FAILED = 1,
    TERRACOTTA_ERROR_NETWORK_JOIN_FAILED = 2,
    TERRACOTTA_ERROR_ROOM_CREATE_FAILED = 3,
    TERRACOTTA_ERROR_ROOM_JOIN_FAILED = 4,
    TERRACOTTA_ERROR_INVALID_PARAMETER = 5,
    TERRACOTTA_ERROR_NETWORK_ERROR = 6,
    TERRACOTTA_ERROR_UNKNOWN = 7
} terracotta_error_t;

// MARK: - Structs

typedef struct {
    char network_id[TERRACOTTA_MAX_NETWORK_ID_LEN];
    char node_id[TERRACOTTA_MAX_NODE_ID_LEN];
    bool is_online;
    uint32_t port;
} terracotta_node_info_t;

typedef struct {
    char room_code[TERRACOTTA_MAX_ROOM_CODE_LEN];
    char player_name[TERRACOTTA_MAX_PLAYER_NAME_LEN];
    bool is_host;
    uint32_t player_count;
    char server_address[64];
    uint16_t server_port;
} terracotta_room_info_t;

// MARK: - ZeroTier Node Functions

/**
 * Initialize ZeroTier node with the given node ID
 * @param node_id ZeroTier node ID string
 * @return true if successful, false otherwise
 */
bool terracotta_start_node(const char *node_id);

/**
 * Stop the ZeroTier node
 */
void terracotta_stop_node(void);

/**
 * Join a ZeroTier network
 * @param network_id ZeroTier network ID string
 * @return true if successful, false otherwise
 */
bool terracotta_join_network(const char *network_id);

/**
 * Leave a ZeroTier network
 * @param network_id ZeroTier network ID string
 * @return true if successful, false otherwise
 */
bool terracotta_leave_network(const char *network_id);

/**
 * Get current node status
 * @return JSON string containing node status
 */
const char *terracotta_get_node_status(void);

// MARK: - Room Management Functions

/**
 * Create a new room
 * @param room_code Room code string
 * @param player_name Player name string
 * @return true if successful, false otherwise
 */
bool terracotta_create_room(const char *room_code, const char *player_name);

/**
 * Join an existing room
 * @param room_code Room code string
 * @param player_name Player name string
 * @return true if successful, false otherwise
 */
bool terracotta_join_room(const char *room_code, const char *player_name);

/**
 * Leave current room
 */
void terracotta_leave_room(void);

/**
 * Get current room status
 * @return JSON string containing room status
 */
const char *terracotta_get_room_status(void);

// MARK: - State Management Functions

/**
 * Get current application state
 * @return JSON string containing current state
 */
const char *terracotta_get_state(void);

/**
 * Set application to waiting state
 */
void terracotta_set_waiting_state(void);

/**
 * Set application to scanning state
 * @param room_code Optional room code
 * @param player_name Optional player name
 */
void terracotta_set_scanning_state(const char *room_code, const char *player_name);

/**
 * Set application to hosting state
 * @param room_code Room code
 * @param player_name Player name
 */
void terracotta_set_hosting_state(const char *room_code, const char *player_name);

/**
 * Set application to guesting state
 * @param room_code Room code
 * @param player_name Player name
 */
void terracotta_set_guesting_state(const char *room_code, const char *player_name);

// MARK: - Utility Functions

/**
 * Initialize logging system
 * @param log_path Path to log file
 */
void terracotta_init_logging(const char *log_path);

/**
 * Get Terracotta version
 * @return Version string
 */
const char *terracotta_get_version(void);

/**
 * Get last error message
 * @return Error message string
 */
const char *terracotta_get_error_message(void);

/**
 * Get node information
 * @param node_info Output structure for node information
 * @return true if successful, false otherwise
 */
bool terracotta_get_node_info(terracotta_node_info_t *node_info);

/**
 * Get room information
 * @param room_info Output structure for room information
 * @return true if successful, false otherwise
 */
bool terracotta_get_room_info(terracotta_room_info_t *room_info);

// MARK: - Callback Functions

/**
 * State change callback function type
 * @param state JSON string containing new state
 */
typedef void (*terracotta_state_callback_t)(const char *state);

/**
 * Error callback function type
 * @param error JSON string containing error information
 */
typedef void (*terracotta_error_callback_t)(const char *error);

/**
 * Log callback function type
 * @param log_message Log message string
 */
typedef void (*terracotta_log_callback_t)(const char *log_message);

/**
 * Set state change callback
 * @param callback Callback function
 */
void terracotta_set_state_callback(terracotta_state_callback_t callback);

/**
 * Set error callback
 * @param callback Callback function
 */
void terracotta_set_error_callback(terracotta_error_callback_t callback);

/**
 * Set log callback
 * @param callback Callback function
 */
void terracotta_set_log_callback(terracotta_log_callback_t callback);

#ifdef __cplusplus
}
#endif

#endif /* terracotta_h */