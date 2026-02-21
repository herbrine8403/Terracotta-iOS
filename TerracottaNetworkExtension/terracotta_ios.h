#ifndef terracotta_ios_h
#define terracotta_ios_h

#ifdef __cplusplus
extern "C" {
#endif

// Run the network instance
int run_network_instance(const char *cfg_str, const char **err_msg);

// Stop the network instance
int stop_network_instance();

// Register stop callback
int register_stop_callback(void (*callback)(), const char **err_msg);

// Register running info callback
int register_running_info_callback(void (*callback)(), const char **err_msg);

// Create a Terracotta room
int create_room(const char *room_name, const char **err_msg, const char **result);

// Join a Terracotta room
int join_room(const char *room_code, const char **err_msg);

#ifdef __cplusplus
}
#endif

#endif /* terracotta_ios_h */
