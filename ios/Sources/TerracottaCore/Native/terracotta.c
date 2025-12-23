//
//  terracotta.c
//  TerracottaCore
//
//  Native C implementation for Terracotta iOS adaptation
//

#include "terracotta.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// MARK: - Global Variables

static terracotta_state_callback_t g_state_callback = NULL;
static terracotta_error_callback_t g_error_callback = NULL;
static terracotta_log_callback_t g_log_callback = NULL;

static char g_error_message[TERRACOTTA_MAX_ERROR_MESSAGE_LEN] = {0};
static char g_log_buffer[TERRACOTTA_MAX_LOG_MESSAGE_LEN] = {0};
static bool g_node_started = false;

// MARK: - Helper Functions

static void set_error(const char *message) {
    if (message && strlen(message) < TERRACOTTA_MAX_ERROR_MESSAGE_LEN) {
        strncpy(g_error_message, message, TERRACOTTA_MAX_ERROR_MESSAGE_LEN - 1);
        g_error_message[TERRACOTTA_MAX_ERROR_MESSAGE_LEN - 1] = '\0';
    }
    
    if (g_error_callback) {
        g_error_callback(g_error_message);
    }
}

static void log_message(const char *level, const char *message) {
    if (!message) return;
    
    snprintf(g_log_buffer, TERRACOTTA_MAX_LOG_MESSAGE_LEN, "[%s]: %s", level, message);
    
    if (g_log_callback) {
        g_log_callback(g_log_buffer);
    }
}

// MARK: - ZeroTier Node Functions

bool terracotta_start_node(const char *node_id) {
    if (!node_id) {
        set_error("Node ID cannot be null");
        return false;
    }
    
    if (g_node_started) {
        set_error("Node is already started");
        return false;
    }
    
    log_message("INFO", "Starting ZeroTier node");
    
    // TODO: Implement actual ZeroTier node startup
    // This would involve calling the ZeroTier libzt API
    // For now, we simulate the startup
    
    g_node_started = true;
    log_message("INFO", "ZeroTier node started successfully");
    
    return true;
}

void terracotta_stop_node(void) {
    if (!g_node_started) {
        return;
    }
    
    log_message("INFO", "Stopping ZeroTier node");
    
    // TODO: Implement actual ZeroTier node shutdown
    // This would involve calling the ZeroTier libzt API
    
    g_node_started = false;
    log_message("INFO", "ZeroTier node stopped");
}

bool terracotta_join_network(const char *network_id) {
    if (!network_id) {
        set_error("Network ID cannot be null");
        return false;
    }
    
    if (!g_node_started) {
        set_error("Node is not started");
        return false;
    }
    
    log_message("INFO", "Joining ZeroTier network");
    
    // TODO: Implement actual ZeroTier network join
    // This would involve calling the ZeroTier libzt API
    
    return true;
}

bool terracotta_leave_network(const char *network_id) {
    if (!network_id) {
        set_error("Network ID cannot be null");
        return false;
    }
    
    if (!g_node_started) {
        set_error("Node is not started");
        return false;
    }
    
    log_message("INFO", "Leaving ZeroTier network");
    
    // TODO: Implement actual ZeroTier network leave
    // This would involve calling the ZeroTier libzt API
    
    return true;
}

const char *terracotta_get_node_status(void) {
    static char status_buffer[512];
    
    if (!g_node_started) {
        snprintf(status_buffer, sizeof(status_buffer),
                "{\"status\":\"stopped\",\"node_id\":\"\",\"network_id\":\"\"}");
    } else {
        // TODO: Get actual node status from ZeroTier
        snprintf(status_buffer, sizeof(status_buffer),
                "{\"status\":\"online\",\"node_id\":\"1234567890\",\"network_id\":\"abcdef1234\"}");
    }
    
    return status_buffer;
}

// MARK: - Room Management Functions

bool terracotta_create_room(const char *room_code, const char *player_name) {
    if (!room_code || !player_name) {
        set_error("Room code and player name cannot be null");
        return false;
    }
    
    log_message("INFO", "Creating room");
    
    // TODO: Implement actual room creation
    // This would involve calling the Terracotta core logic
    
    return true;
}

bool terracotta_join_room(const char *room_code, const char *player_name) {
    if (!room_code || !player_name) {
        set_error("Room code and player name cannot be null");
        return false;
    }
    
    log_message("INFO", "Joining room");
    
    // TODO: Implement actual room joining
    // This would involve calling the Terracotta core logic
    
    return true;
}

void terracotta_leave_room(void) {
    log_message("INFO", "Leaving room");
    
    // TODO: Implement actual room leaving
    // This would involve calling the Terracotta core logic
}

const char *terracotta_get_room_status(void) {
    static char status_buffer[512];
    
    // TODO: Get actual room status from Terracotta core
    snprintf(status_buffer, sizeof(status_buffer),
            "{\"room_code\":\"\",\"player_name\":\"\",\"is_host\":false,\"player_count\":0}");
    
    return status_buffer;
}

// MARK: - State Management Functions

const char *terracotta_get_state(void) {
    static char state_buffer[512];
    
    // TODO: Get actual state from Terracotta core
    snprintf(state_buffer, sizeof(state_buffer),
            "{\"state\":\"waiting\",\"index\":0}");
    
    return state_buffer;
}

void terracotta_set_waiting_state(void) {
    log_message("INFO", "Setting waiting state");
    
    // TODO: Implement actual state change
    if (g_state_callback) {
        g_state_callback("{\"state\":\"waiting\",\"index\":1}");
    }
}

void terracotta_set_scanning_state(const char *room_code, const char *player_name) {
    log_message("INFO", "Setting scanning state");
    
    // TODO: Implement actual state change
    if (g_state_callback) {
        g_state_callback("{\"state\":\"host-scanning\",\"index\":2}");
    }
}

void terracotta_set_hosting_state(const char *room_code, const char *player_name) {
    log_message("INFO", "Setting hosting state");
    
    // TODO: Implement actual state change
    if (g_state_callback) {
        g_state_callback("{\"state\":\"host-ok\",\"index\":3}");
    }
}

void terracotta_set_guesting_state(const char *room_code, const char *player_name) {
    log_message("INFO", "Setting guesting state");
    
    // TODO: Implement actual state change
    if (g_state_callback) {
        g_state_callback("{\"state\":\"guest-connecting\",\"index\":4}");
    }
}

// MARK: - Utility Functions

void terracotta_init_logging(const char *log_path) {
    log_message("INFO", "Initializing logging system");
    
    // TODO: Initialize actual logging to file
}

const char *terracotta_get_version(void) {
    return "1.0.0-iOS";
}

const char *terracotta_get_error_message(void) {
    return g_error_message;
}

bool terracotta_get_node_info(terracotta_node_info_t *node_info) {
    if (!node_info) {
        return false;
    }
    
    // TODO: Get actual node information
    memset(node_info, 0, sizeof(terracotta_node_info_t));
    
    if (g_node_started) {
        strcpy(node_info->network_id, "abcdef1234");
        strcpy(node_info->node_id, "1234567890");
        node_info->is_online = true;
        node_info->port = 9993;
    }
    
    return true;
}

bool terracotta_get_room_info(terracotta_room_info_t *room_info) {
    if (!room_info) {
        return false;
    }
    
    // TODO: Get actual room information
    memset(room_info, 0, sizeof(terracotta_room_info_t));
    
    return true;
}

// MARK: - Callback Functions

void terracotta_set_state_callback(terracotta_state_callback_t callback) {
    g_state_callback = callback;
}

void terracotta_set_error_callback(terracotta_error_callback_t callback) {
    g_error_callback = callback;
}

void terracotta_set_log_callback(terracotta_log_callback_t callback) {
    g_log_callback = callback;
}