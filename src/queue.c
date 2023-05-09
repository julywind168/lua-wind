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
	int len_slot;
	int len_data;
	char *content;
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
		m->len_slot  = LDEFAULT_SLOT;
		m->len_data  = 0;
		m->content 	 = malloc(sizeof(char) * LDEFAULT_SLOT) CHECKNULL(m->content)

		q->data[i] = m;
	}

	return q;
}

bool
qpush(Queue *queue, const char *content, int length)
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
	if (length > m->len_slot) {
		m->content = realloc(m->content, length) CHECKNULL(m->content)
		m->len_slot = length;
	}

	m->len_data = length;
	memcpy(m->content, content, length);
	m->flag = FILLED;

	return true;
}

bool
qpop(Queue *queue, char**content, int *length)
{

	// printf("readindex: %llu\n", queue->readindex);
	int index = queue->readindex % LQUEUE;

	Message *m = queue->data[index];

	if (m->flag == EMPTY) {
		return false;
	} else {
		*content = m->content;
		*length = m->len_data;

		m->flag = EMPTY;
		queue->readindex++;
		// queue->count--;
		return true;
	}
}

void
queue_free(Queue *queue)
{  
	for (int i = 0; i < LQUEUE; ++i)
	{
		free(queue->data[i]->content);
		free(queue->data);
	}
	free(queue);
}