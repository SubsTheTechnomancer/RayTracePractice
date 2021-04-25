#include<glad/glad.h>
#include<GLFW/glfw3.h>
#include "stb_image.h"
#include "external/glm/glm.hpp"
#include "external/glm/gtc/matrix_transform.hpp"

#include<iostream>
#include<fstream>
#include<string>
#include<sstream>
#include <vector>

using namespace std;

int width = 900;
int height = 900;
int scene = 1;

const char* vertexS = "#version 430\n"
"layout(location = 0) in vec3 Position;\n"
"layout(location = 1) in vec2 aTexCoord;\n"
"out vec2 TexCoord;\n"
"void main() {\n"
"gl_Position = vec4(Position, 1.0);\n"
"TexCoord = aTexCoord;\n"
"};";

const char *fragmentS = "#version 430\n"
"out vec4 FragColor;\n"
"in vec2 TexCoord;\n"
"uniform sampler2D ourTexture;\n"
"void main() {\n"
"FragColor = texture(ourTexture,TexCoord);\n"
"};";

float vertices[] = {
	1,1,0,1,1,
	1,-1,0,1,0,
	-1,1,0,0,1,
	1,-1,0,1,0,
	-1,-1,0,0,0,
	-1,1,0,0,1
};

string GetShaderSource(string filepath) {
	ifstream t(filepath);
	stringstream buffer;
	buffer << t.rdbuf();
	t.close();
	string s = buffer.str();
	return s;
}

unsigned int loadCubemap(vector<std::string> faces)
{
	unsigned int textureID;
	glGenTextures(1, &textureID);
	glBindTexture(GL_TEXTURE_CUBE_MAP, textureID);

	int width, height, nrChannels;
	for (unsigned int i = 0; i < faces.size(); i++)
	{
		unsigned char* data = stbi_load(faces[i].c_str(), &width, &height, &nrChannels, 0);
		if (data)
		{
			glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i,
				0, GL_RGB, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, data
			);
			stbi_image_free(data);
		}
		else
		{
			std::cout << "Cubemap tex failed to load at path: " << faces[i] << std::endl;
			stbi_image_free(data);
		}
	}
	glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);

	return textureID;
}

int main() {

	GLFWwindow* window;

	if (!glfwInit())
		return -1;

	glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT, GL_TRUE);
	window = glfwCreateWindow(width, height, "Raytracing", NULL, NULL);
	if (!window) {
		glfwTerminate();
		return -1;
	}

	glfwMakeContextCurrent(window);
	glfwSwapInterval(1);

	if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
		cout << "GLAD failed to initialize" << endl;
		return -1;
	}

	glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);

	cout << glGetString(GL_VERSION) << endl;

	//Texture definition

	int tw = width, th = height;
	GLuint tex_out;
	glGenTextures(1, &tex_out);
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, tex_out);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, tw, th, 0, GL_RGBA, GL_FLOAT, NULL);
	glBindImageTexture(0, tex_out, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_RGBA32F);

	glBindTexture(GL_TEXTURE_2D, 0);

	//Work groups

	int work_grp_cnt[3];

	for (int i = 0; i < 3; i++) glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_COUNT, i, &work_grp_cnt[i]);
	cout << "Global work group counts x:" << work_grp_cnt[0] << " y: " << work_grp_cnt[1] << " z: " << work_grp_cnt[2] << endl;

	int work_grp_inv;
	glGetIntegerv(GL_MAX_COMPUTE_WORK_GROUP_INVOCATIONS, &work_grp_inv);
	cout << "Local work group invocations: " << work_grp_inv<<endl;

	string shaderSource;

	shaderSource = GetShaderSource("Vertex.glsl");
	const char* vertexSource;
	vertexSource = shaderSource.c_str();

	shaderSource = GetShaderSource("Fragment.glsl");
	const char* fragmentSource;
	fragmentSource = shaderSource.c_str();

	if(scene==0)
		shaderSource = GetShaderSource("computeShader_bg.glsl");
	else if(scene==1)
		shaderSource = GetShaderSource("computeShader_lighting.glsl");

	const char* computeSource;
	computeSource = shaderSource.c_str();

	GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
	glShaderSource(vertexShader, 1, &vertexS, NULL);
	glCompileShader(vertexShader);
	int success;
	char infoLog[512];
	glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
	if (!success) {
		cout << "Vertex error" << endl;
		glGetShaderInfoLog(vertexShader, 512, NULL, infoLog);
		cout << infoLog << endl;
	}

	GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
	glShaderSource(fragmentShader, 1, &fragmentS, NULL);
	glCompileShader(fragmentShader);
	glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &success);
	if (!success) {
		cout << "Fragment error" << endl;
		glGetShaderInfoLog(fragmentShader, 512, NULL, infoLog);
		cout << infoLog << endl;
	}

	GLuint rayShader = glCreateShader(GL_COMPUTE_SHADER);
	glShaderSource(rayShader, 1, &computeSource, NULL);
	glCompileShader(rayShader);
	glGetShaderiv(rayShader, GL_COMPILE_STATUS, &success);
	if (!success) {
		cout << "ray error" << endl;
		glGetShaderInfoLog(rayShader, 512, NULL, infoLog);
		cout << infoLog << endl;
	}

	GLuint quadProgram = glCreateProgram();
	glAttachShader(quadProgram, vertexShader);
	glAttachShader(quadProgram, fragmentShader);
	glLinkProgram(quadProgram);

	GLuint rayProgram = glCreateProgram();
	glAttachShader(rayProgram, rayShader);
	glLinkProgram(rayProgram);

	glDeleteShader(vertexShader);
	glDeleteShader(fragmentShader);
	glDeleteShader(rayShader);

	//Buffers
	GLuint VAO;
	glGenVertexArrays(1, &VAO);
	
	GLuint VBO;
	glGenBuffers(1, &VBO);
	glBindVertexArray(VAO);
	glBindBuffer(GL_ARRAY_BUFFER, VBO);
	glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)0);
	glEnableVertexAttribArray(0);
	glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)(3 * sizeof(float)));
	glEnableVertexAttribArray(1);

	float mesh[] = 
	{
		1,1,0,0,
		1,0,0,0,
		0,1,0,0,
		1,0,0,0,
		0,0,0,0,
		0,1,0,0,
	};

	GLuint meshBlock;
	glGenBuffers(1, &meshBlock);
	glBindBuffer(GL_UNIFORM_BUFFER, meshBlock);
	glBufferData(GL_UNIFORM_BUFFER, sizeof(mesh), NULL, GL_STATIC_DRAW);
	glBindBuffer(GL_UNIFORM_BUFFER, 0);

	glBindBufferBase(GL_UNIFORM_BUFFER, 0, meshBlock);

	std::string prefix = "res/skyboxes/ocean/";
	vector<std::string> faces
	{
			prefix + "right.jpg",
			prefix + "left.jpg",
			prefix + "top.jpg",
			prefix + "bottom.jpg",
			prefix + "front.jpg",
			prefix + "back.jpg"
	};
	unsigned int cubemapTexture = loadCubemap(faces);

	float aperture[4] =
	{
		0.0f, 0.0f, 10.0f, 1.0f
	};
	float seed = 0.5f;
       
	//Loop
	while (!glfwWindowShouldClose(window)) {

		glUseProgram(rayProgram);
		glDispatchCompute((GLuint)tw, (GLuint)th, 1);
		int sizeLoc = glGetUniformLocation(rayProgram, "size");
		glUniform1f(sizeLoc, sizeof(mesh) / 4);
		int seedLoc = glGetUniformLocation(rayProgram, "seed");
		glUniform1f(seedLoc, seed);
		seed += 3.1415f;
		int appertureLoc = glGetUniformLocation(rayProgram, "aperture");
		glUniform4fv(appertureLoc, 1, aperture);
		glBindTexture(GL_TEXTURE_CUBE_MAP, cubemapTexture);

		glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
		glClear(GL_COLOR_BUFFER_BIT);
		glUseProgram(quadProgram);
		glBindVertexArray(VAO);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, tex_out);
		glDrawArrays(GL_TRIANGLES, 0, 6);

		glBindBuffer(GL_UNIFORM_BUFFER, meshBlock);
		glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(mesh), mesh);
		glBindBuffer(GL_UNIFORM_BUFFER, 0);

		glfwPollEvents();

		glfwSwapBuffers(window);
	}

	return 0;
}