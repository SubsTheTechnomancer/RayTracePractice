#include<glad/glad.h>
#include<GLFW/glfw3.h>

#include<iostream>
#include<fstream>
#include<string>
#include<sstream>

using namespace std;

int width = 1000;
int height = 1000;

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

	shaderSource = GetShaderSource("ComputeShader.glsl");
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

	//Loop

	while (!glfwWindowShouldClose(window)) {
		glUseProgram(rayProgram);
		glDispatchCompute((GLuint)tw, (GLuint)th, 1);

		int sizeLoc = glGetUniformLocation(rayProgram, "size");
		glUniform1f(sizeLoc, sizeof(mesh) / 4 * sizeof(float));

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
