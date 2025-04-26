<script setup lang="ts">
import { onMounted, ref } from 'vue'
import axios from 'axios'
import { Chart } from 'chart.js/auto'

interface Option {
  id: number
  text: string
  votes: number
}

const options = ref<Option[]>([])
const selected = ref<number>()
const hasVoted = ref<boolean>(localStorage.getItem('hasVoted') === 'true')
let chart: Chart | null = null

// 获取初始数据
const fetchData = async () => {
  try {
    const res = await axios.get('http://localhost:8080/api/poll')
    if (res.data && res.data.Options && Array.isArray(res.data.Options)) {
      // 将API返回的Options数组转换为前端需要的格式
      options.value = res.data.Options.map((opt: { ID: number; Text: string; Votes: number }) => ({
        id: opt.ID,
        text: opt.Text,
        votes: opt.Votes
      }))
      console.log('成功获取数据，选项数量:', options.value.length)
    } else {
      console.warn('API返回的数据格式不正确:', res.data)
      options.value = []
    }
  } catch (error) {
    console.error('获取数据失败:', error)
    options.value = []
    throw error
  }
}

// 提交投票
const submitVote = async () => {
  if (!selected.value || hasVoted.value) return
  try {
    // 修正API路径为正确的投票端点
    await axios.post(`http://localhost:8080/api/poll/vote/${selected.value}`)
    // 设置已投票状态
    hasVoted.value = true
    // 保存投票状态到本地存储
    localStorage.setItem('hasVoted', 'true')
    // 提交后重新获取数据并更新图表
    await fetchData()
    updateChart()
  } catch (error) {
    console.error('提交投票失败:', error)
  }
}

// 初始化图表
const initChart = () => {
  // 增强防御性检查，确保options.value存在且是数组
  if (!options.value || !Array.isArray(options.value) || options.value.length === 0) {
    console.warn('初始化图表失败：没有选项数据或数据格式不正确')
    return
  }
  
  const ctx = document.getElementById('chart') as HTMLCanvasElement
  if (!ctx) {
    console.error('初始化图表失败：找不到canvas元素')
    return
  }
  
  // 如果已经存在图表实例，先销毁它
  if (chart) {
    chart.destroy()
  }
  
  try {
    console.log('初始化图表，数据:', options.value)
    chart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: options.value.map(o => o.text),
        datasets: [{
          label: '投票数',
          data: options.value.map(o => o.votes),
          backgroundColor: 'rgba(52, 152, 219, 0.7)',
          borderColor: 'rgba(41, 128, 185, 1)',
          borderWidth: 1,
          borderRadius: 8,
          hoverBackgroundColor: 'rgba(52, 152, 219, 0.9)',
          barThickness: 50, // 设置柱状条宽度
          maxBarThickness: 70, // 最大宽度限制
          barPercentage: 0.8 // 柱状条宽度百分比
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        aspectRatio: 1.5, // 设置更合适的宽高比
        plugins: {
          legend: {
            labels: {
              font: {
                size: 14,
                weight: 'bold'
              }
            }
          },
          tooltip: {
            backgroundColor: 'rgba(0, 0, 0, 0.7)',
            padding: 10,
            titleFont: {
              size: 14
            },
            bodyFont: {
              size: 13
            },
            displayColors: false
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: {
              color: 'rgba(200, 200, 200, 0.2)'
            },
            ticks: {
              font: {
                size: 12
              },
              precision: 0
            }
          },
          x: {
            grid: {
              display: false
            },
            ticks: {
              font: {
                size: 12,
                weight: 'bold'
              }
            }
          }
        },
        animation: {
          duration: 1000,
          easing: 'easeOutQuart'
        }
      }
    })
  } catch (error) {
    console.error('创建图表时发生错误:', error)
  }
}

// 更新图表数据
const updateChart = () => {
  // 增强防御性检查
  if (!chart) {
    console.warn('更新图表失败：图表实例不存在')
    return
  }
  
  if (!options.value || !Array.isArray(options.value) || options.value.length === 0) {
    console.warn('更新图表失败：没有有效的选项数据')
    return
  }
  
  try {
    chart.data.labels = options.value.map(o => o.text)
    chart.data.datasets[0].data = options.value.map(o => o.votes)
    chart.update()
  } catch (error) {
    console.error('更新图表时发生错误:', error)
  }
}

// 建立 SSE 连接
onMounted(async () => {
  try {
    await fetchData()
    
    // 确保数据已成功获取
    if (options.value && Array.isArray(options.value) && options.value.length > 0) {
      console.log('数据获取成功，选项数量:', options.value.length)
      // 确保在DOM更新后初始化图表
      setTimeout(() => {
        initChart()
      }, 100) // 增加延迟时间，确保DOM完全更新
    } else {
      console.warn('数据获取成功，但没有选项数据或格式不正确')
    }
    
    // 建立SSE连接
    let eventSource = new EventSource('http://localhost:8080/sse/poll')
    
    eventSource.onmessage = (e) => {
      console.log('收到SSE更新:', e.data)
      try {
        const parsedData = JSON.parse(e.data)
        if (Array.isArray(parsedData) && parsedData.length > 0) {
          // 将SSE返回的数据转换为前端需要的格式
          options.value = parsedData.map(opt => ({
            id: opt.ID,
            text: opt.Text,
            votes: opt.Votes
          }))
          updateChart()
        } else {
          console.warn('收到的SSE数据格式不正确:', parsedData)
        }
      } catch (error) {
        console.error('解析SSE数据失败:', error)
      }
    }
    
    eventSource.onerror = (error) => {
      console.error('SSE连接错误:', error)
      // 尝试重新连接
      setTimeout(() => {
        console.log('尝试重新连接SSE...')
        eventSource.close()
        // 重新建立连接
        try {
          const newEventSource = new EventSource('http://localhost:8080/sse/poll')
          eventSource = newEventSource
          console.log('SSE连接已重新建立')
        } catch (reconnectError) {
          console.error('SSE重连失败:', reconnectError)
        }
      }, 5000)
    }
  } catch (error) {
    console.error('初始化失败:', error)
  }
})
</script>

<template>
  <div class="poll-container">
    <h2>你最喜欢的编程语言是？</h2>
    <div 
      v-for="opt in options" 
      :key="opt.id" 
      class="option-container"
      :class="{ 'disabled': hasVoted }"
      @click="!hasVoted && (selected = opt.id)"
    >
      <input 
        type="radio" 
        :id="`opt-${opt.id}`" 
        :value="opt.id"
        v-model="selected"
        :disabled="hasVoted"
      >
      <label :for="`opt-${opt.id}`">{{ opt.text }}</label>
    </div>
    <button @click="submitVote" :disabled="hasVoted || !selected">{{ hasVoted ? '已投票' : '提交投票' }}</button>
    <canvas id="chart"></canvas>
  </div>
</template>

<style scoped>
.poll-container {
  max-width: 700px;
  margin: 2rem auto;
  padding: 30px;
  border-radius: 12px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
  background-color: white;
  transition: all 0.3s ease;
}

h2 {
  text-align: center;
  margin-bottom: 25px;
  color: #2c3e50;
  font-size: 1.8rem;
  font-weight: 600;
}

.option-container {
  margin-bottom: 12px;
  padding: 8px 16px;
  border-radius: 6px;
  transition: all 0.2s ease;
  cursor: pointer;
  display: flex;
  align-items: center;
  background-color: rgba(255, 255, 255, 0.8);
}

.option-container:hover:not(.disabled) {
  background-color: rgba(240, 240, 240, 0.9);
  transform: translateX(4px);
}

.option-container.disabled {
  cursor: not-allowed;
  opacity: 0.7;
}

input[type="radio"] {
  margin-right: 12px;
  cursor: pointer;
  transform: scale(1.2);
}

input[type="radio"]:disabled + label {
  cursor: not-allowed;
  opacity: 0.7;
}

label {
  font-size: 1.1rem;
  font-weight: 500;
  color: #34495e;
  transition: color 0.2s;
  cursor: inherit;
  user-select: none;
  flex: 1;
}

button {
  display: block;
  margin: 30px auto;
  padding: 12px 28px;
  background-color: #3498db;
  color: white;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  font-size: 1.1rem;
  font-weight: 500;
  letter-spacing: 0.5px;
  transition: all 0.3s ease;
  box-shadow: 0 2px 5px rgba(0, 0, 0, 0.1);
}

button:hover:not(:disabled) {
  background-color: #2980b9;
  transform: translateY(-2px);
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
}

button:disabled {
  background-color: #cccccc;
  cursor: not-allowed;
  opacity: 0.7;
}

canvas {
  margin-top: 40px;
  width: 100% !important;
  height: 500px !important; /* 增加图表高度 */
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.05);
  background-color: rgba(250, 250, 250, 0.8);
  padding: 15px;
  display: block; /* 确保正确显示 */
}
</style>