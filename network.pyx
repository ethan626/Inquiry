#!/bin/python
import sys
import numpy as np
cimport numpy as np
import itertools
sys.path.append("../")
from Inquiry.utilities import * 
np.random.seed(1)

class Layer():
    """ Hidden Layer of a Feed Forward Neural Network """

    def __init__(self, unsigned int in_size, unsigned int out_size, learning_rate=1, tanh=False, bias=0):
        """ Constructor Method 
        
           This layer-> 
         this weight matrix                        Next Layer |
                                                              v
        

        """

        cdef double[:,:] weights = 2 * np.random.random((in_size, out_size)) - 1 
        # cdef double[:,:] deltas #= np.zeros((in_size, out_size))  
        # cdef double[:,:] neuron_outputs #= np.zeros((1, out_size))
        # cdef double[:,:] neuron_inputs #= np.zeros((1, in_size))

        self.weights = weights 
        self.input_size = in_size
        self.output_size = out_size
        self.deltas = None 
        self.neuron_outputs = None
        self.neuron_inputs = None
        self.learning_rate = learning_rate
        self.tanh = tanh  
        self.bias = bias
        
    def get_weights(self):
        return self.weights
    
    def activation(self, np.ndarray x):
        """ Sigmoid activation function """
        if self.tanh:
            return np.tanh(x)
        else:
            return 1/(1+np.exp(-x))

    def derivative(self, np.ndarray x):
        """ Sigmoid derivative """
        if self.tanh:
            return 1-np.tanh(x) ** 2
        return x * (1-x)
    
    def predict(self, np.ndarray x):
        """ Layers prediction for input *x* """
        self.neuron_inputs = np.array(x)
        self.neuron_outputs = self.activation(x)
        return np.dot(self.activation(x), self.weights) + self.bias 

    def get_deltas(self, next_layer=None, prev_layer=None, **kwargs): 
        """ Calcuates the deltas for a layer for an entire epoch """
        self.deltas = np.dot(next_layer.deltas, self.weights.T) * self.derivative(self.neuron_outputs) 
        return self.deltas
        
    def adjust_weights(self,  prev_layer=None, next_layer=None, *args, **kwargs):
        """ Adjusts the weights between the layer and the previous layer """
        cdef double[:,:] deltas = next_layer.deltas
        cdef double[:,:] adjustments = self.learning_rate * np.dot(self.neuron_outputs.T, deltas)
        self.weights += np.array(adjustments)

class OutputLayer(Layer):
    """ Output Layer """

    def __init__(self, learning_rate=1, tanh=False, bias=0):
        """ """
        
        # cdef double[:,:] deltas 
        # cdef double[:,:] neuron_outputs
        # cdef double[:,:] neuron_inputs
        
        self.deltas = None 
        self.neuron_outputs = None 
        self.neuron_inputs = None 
        self.learning_rate = learning_rate
        # self.weights = []       # Ununsed  
        self.tanh = tanh
        self.bias = bias

    def predict(self, np.ndarray x):
        """ """
        self.neuron_inputs = np.array(x)
        self.neuron_outputs = self.activation(x) + self.bias
        return self.neuron_outputs

    def get_deltas(self, np.ndarray error, *args, **kwargs):
        """ """
        self.deltas = error * self.derivative(self.neuron_outputs)
        return self.deltas

    def adjust_weights(self,  error, *args, **kwargs):
        """ """
        self.get_deltas(error)
    
class InputLayer(Layer):
    """ Input Layer of the network """

    def __init__(self, unsigned int in_size, unsigned int out_size, learning_rate=1, bias=0):
        """  Init method. Weights are initialized to the identity matrix as the raw data is passed forward"""
        cdef double[:,:] weights = 2 * np.random.random((in_size, out_size)) - 1 
        # cdef double[:,:] deltas 
        # cdef double[:,:] neuron_outputs
        # cdef double[:,:] neuron_inputs

        self.weights = weights 
        self.input_size = in_size
        self.deltas = None 
        self.neuron_outputs = None 
        self.neuron_inputs = None
        self.learning_rate = learning_rate
        self.bias = bias
        
    def predict(self, np.ndarray x):
        """ Input Layer predict. Passes the raw data forward  """
        self.neuron_inputs = np.array(x)
        self.neuron_outputs = np.array(x)
        return np.dot(x, self.weights) + self.bias
    
    def adjust_weights(self, np.ndarray error, prev_layer=None, next_layer=None, **kwargs): 
        """ Adjusts the weights between the layer and the previous layer """
        deltas = next_layer.deltas
        adjustments = self.learning_rate * np.dot(self.neuron_inputs.T, deltas)
        self.weights += np.array(adjustments) # Adjustments is a memory view slice, need to convert to numpy array to add them 
        
class NeuralNetwork():
    """ Feed Forward Neural Network """

    def __init__(self):
        """ self.layers = a list of all layers in the network. Currently the hidden layers are square matricies of the same size as the input shape """
        self.layers = np.array([])

    def add_input_layer(self, input_shape, output_shape, learning_rate=.003):
        """ Add an input layer to the network """
        self.layers = np.append(self.layers, InputLayer(input_shape, output_shape, learning_rate=learning_rate))

    def add_output_layer(self, learning_rate=.003, tanh=False):
        """ Add an output neuron to the network """
        self.layers = np.append(self.layers, OutputLayer(learning_rate=learning_rate, tanh=tanh))

    def add_layer(self, input_shape, output_shape, learning_rate=.003, tanh=False):
        """ Add a layer to the network """
        self.layers = np.append(self.layers, Layer(input_shape, output_shape, learning_rate=learning_rate, tanh=tanh))

    def weights(self):
        """ Returns a numpy array of the weights of the network, not counting the input layer with the weights of the layers closest to the input layers coming first """
        return np.array([layer.weights for layer in self.layers])

    def num_layers(self):
        """ Returns the number of layers in the network """
        return len(self.layers)

    def deltas(self):
        """ Returns a matrix of the deltas of each layer """
        return np.array([layer.deltas() for layer in self.layers])

    def neuron_outputs(self):
        """ Neuron outputs for each layer """
        return np.array([layers.neuron_outputs for layer in self.layers])

    def predict(self, x, one_hot=False):
        """ Prediction of input *x*. *one_hot* returns a one hot encoded prediction  """
        for layer in self.layers: 
            x = layer.predict(x)
        return x

    def adjust_weights(self, np.ndarray error, **kwargs):
        """ Adjusting of the Layer's weights """

        if len(self.layers) > 2:  
            reversed_layers = [layer for layer in reversed(self.layers[:-1])]
            next_layer = self.layers[-1]
            next_layer.adjust_weights(error)
            
            for prev_layer, layer in zip(reversed_layers[1:], reversed_layers):
                layer.adjust_weights(error=error, prev_layer=prev_layer, next_layer=next_layer)
                layer.get_deltas(next_layer=next_layer, prev_layer=prev_layer)
                next_layer = layer

            self.layers[0].adjust_weights(error=error, next_layer=next_layer)
            
        else:
            self.layers[-1].adjust_weights(error=error)
            self.layers[-2].adjust_weights(error=error, next_layer=self.layers[1])

    def train(self, unsigned int epochs, np.ndarray training_set_inputs, np.ndarray training_set_outputs, loss_function=lambda x,y: x - y):
        """ Train the network """
        cdef np.ndarray error 
        cdef np.ndarray prediction

        for i in range(epochs):
            prediction = self.predict(training_set_inputs) 
            error = loss_function(training_set_outputs, prediction)
            self.adjust_weights(error)

    # def _encode(self, data):    # Need to finish this  
    #     """ Encodes numpy arrays so they can be saved with json """

    #     if isinstance(data, np.ndarray):
    #         return data.tolist()

    #     if isinstance(data, np.int64):
    #         return int(data)

    #     if isinstance(data, Layer):
    #         return {attribute: self._encode(getattr(data, attribute)) for attribute in data.__dict__}

    # def save(self, file_name):  # Needs to call _encode on each attribute of the attributes 
    #     """ Saves the network to a file."""
    #     save_data = {attribute: self._encode(getattr(self, attribute)) for attribute in self.__dict__}
    #     return save_data
    #     with open(file_name, 'a+') as f:
    #         f.write(json.dumps(save_data))
