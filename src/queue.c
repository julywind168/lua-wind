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
	Message *data[LQUEUE];
	_Atomic unsigned long long int readindex;
	_Atomic unsigned long long int writeindex;
};


Queue *
q_initialize()
{
	Queue * q 		= malloc(sizeof(Queue)) CHECKNULL(q)
	q->readindex 	= 0;
	q->writeindex 	= 0;
	// q->count		= 0;

	Message *m = NULL;

	for (int i = 0; i < LQUEUE; ++i)
	{
		m 			 = malloc(sizeof(Message)) CHECKNULL(m)
		m->flag 	 = EMPTY;
		m->data 	 = NULL;
		q->data[i] = m;
	}

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
	
	Message *m = queue->data[index];
	m->data = data;
	m->flag = FILLED;

	return true;
}

void *
q_pop(Queue *queue)
{

	// printf("readindex: %llu\n", queue->readindex);
	int index = queue->readindex % LQUEUE;

	Message *m = queue->data[index];

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
		if (queue->data[i]->flag == FILLED) {
			free(queue->data[i]);
		}
	}
	free(queue);
}