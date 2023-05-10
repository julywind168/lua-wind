#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdatomic.h>

#include "queue.h"

#define CHECKNULL(x) ;if(x == NULL) { perror("Malloc failed."); exit(1); }

#define LQUEUE 2048
#define LDEFAULT_SLOT 512

#define EMPTY 0
#define FILLED 1

struct _message{
	_Atomic char flag;		// 0 is empty, 1 is has data
	void *data;
};

struct _queue{
	_Atomic unsigned long long int readindex;
	_Atomic unsigned long long int writeindex;
	Message messages[LQUEUE];
};


Queue *
q_initialize()
{
	Queue * q 		= calloc(1, sizeof(Queue)) CHECKNULL(q)
	q->readindex 	= 0;
	q->writeindex 	= 0;
	return q;
}

bool
q_push(Queue *queue, void *data)
{
	int index;					
	int count = queue->writeindex - queue->readindex + 1; //2047	-	0    2048     2047 时超载

	if (count == LQUEUE) {
		fprintf(stderr, "queue overload... %llu %llu\n", queue->writeindex, queue->readindex);
		return false;
	}

	if ((count+1)%100 == 0)
		fprintf(stderr, "waring: queue length: %d\n", count+1);

	index = atomic_fetch_add(&queue->writeindex, 1);
	index = index%LQUEUE;
	
	Message *m = queue->messages + index;
	m->data = data;
	m->flag = FILLED;

	return true;
}

void *
q_pop(Queue *queue)
{

	// printf("readindex: %llu\n", queue->readindex);
	int index = queue->readindex % LQUEUE;

	Message *m = queue->messages + index;

	if (m->flag == EMPTY) {
		return NULL;
	} else {
		m->flag = EMPTY;
		queue->readindex++;
		return m->data;
	}
}

void
q_free(Queue *queue)
{  
	for (int i = 0; i < LQUEUE; ++i) {
		if (queue->messages[i].flag == FILLED && queue->messages[i].data) {
			free(queue->messages[i].data);
		}
	}
	free(queue);
}