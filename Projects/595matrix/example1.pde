#include <SPI.h>

#define PWM_STEPS 16
#define FPS 25

#define DATAPIN 11 //MOSI
#define CLOCKPIN 13 //SCK
#define LATCHPIN 10

#define PITCH (8*3) //three bytes per pixel, one byte for red, green and blue

uint8_t buffers[2][PITCH*8];  
volatile uint8_t* frontbuffer;
volatile uint8_t* backbuffer;

volatile uint8_t pwm_step;
volatile uint8_t current_row;
volatile bool newbuffer;
volatile bool vblank;
volatile uint8_t* rowptr;
/*
	we go through each row PWM_STEPS times in order to get us different shades of colour

*/
ISR(TIMER2_COMPA_vect)
{

	if (vblank)
	{
		if (newbuffer)
		{
			volatile uint8_t* temp = frontbuffer;
			frontbuffer = backbuffer;
			backbuffer = temp;
			rowptr = frontbuffer;
			newbuffer=false;
		}
		vblank=false;
	}

	//turn rows off
	SPI.transfer(0);
	digitalWrite(LATCHPIN,HIGH);
	digitalWrite(LATCHPIN,LOW);	

	for (int c=0;c<3;c++) //we process red,green and blue individually
	{
		uint8_t col=0xff;
		for (int x=0;x<8;x++)
		{
			uint8_t b = *(rowptr+x*3+c);
			if (b > pwm_step)
				col &= ~(1<<x);
		}
		SPI.transfer(col);
	}
	SPI.transfer(1<<current_row);
	digitalWrite(LATCHPIN,HIGH);
	digitalWrite(LATCHPIN,LOW);
	
	pwm_step = (pwm_step+1)&(PWM_STEPS-1);

	if (!pwm_step)
	{
		current_row = (current_row+1)&7;
		if (!current_row)
			vblank=true;
		else
			rowptr = frontbuffer+current_row*PITCH;
	}

}

void setup()
{
	frontbuffer = (uint8_t*)&buffers[0];
	backbuffer = (uint8_t*)&buffers[1];
	pinMode(LATCHPIN,OUTPUT);
	pinMode(DATAPIN,OUTPUT);
	pinMode(CLOCKPIN,OUTPUT);

	SPI.begin();

	// setup the interrupt.
	TCCR2A = (1<<WGM21); // clear timer on compare match
	TCCR2B = (1<<CS21); // timer uses main system clock with 1/8 prescale
	OCR2A	 = (F_CPU >> 3) / 8 / (PWM_STEPS-1) / FPS; // Frames per second * 15 passes for brightness * 8 rows
	TIMSK2 = (1<<OCIE2A); // call interrupt on output compare match

}

uint8_t x,y,p,c;
void loop()
{

	for (int i=0;i<sizeof(buffers[0]);i++)
	{
		if (backbuffer[i] > 0)
			backbuffer[i]--; 
	}
	backbuffer[y*8*3+x*3+c]=p;
	p++;

	if (p>PWM_STEPS)
	{
		p=0;
		c++;

		if (c > 2)
		{
			c=0;
			x++;
			if (x>7)
			{
				x=0;
				y++;
				if (y>7)
					y=0; 
			}
		}
	}
	newbuffer=true;
	while(newbuffer) {} //wait until interrupt switches the buffers

}


