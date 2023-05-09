#ifndef STAR_QUEUE_H
#define STAR_QUEUE_H

#include <stdbool.h>

typedef struct _message Message;
typedef struct _queue Queue;



Queue *
q_initialize();


bool
q_push(Queue *queue, void *data);


void *
q_pop(Queue *queue);


void
q_free(Queue *queue);



#endif