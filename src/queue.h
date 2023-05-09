#ifndef STAR_QUEUE_H
#define STAR_QUEUE_H

#include <stdbool.h>

typedef struct _message Message;
typedef struct _queue Queue;



Queue *
q_initialize();


bool
qpush(Queue *queue, const char *content, int length);


bool
qpop(Queue *queue, char**content, int *length);


void
queue_free(Queue *queue);



#endif