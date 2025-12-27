package main

import "C"
import (
	"fmt"
	"os"
	"time"
	"unsafe"

	sls "github.com/aliyun/aliyun-log-go-sdk"
	"github.com/fluent/fluent-bit-go/output"
	"github.com/gogo/protobuf/proto"
)

var hostname, _ = os.Hostname()

//export FLBPluginRegister
func FLBPluginRegister(ctx unsafe.Pointer) int {
	// Gets called only once when the plugin.so is loaded
	return output.FLBPluginRegister(ctx, "alisls", "alisls-fluent-plugin")
}

//export FLBPluginInit
func FLBPluginInit(plugin unsafe.Pointer) int {

	project := &sls.LogProject{
		Name:            output.FLBPluginConfigKey(plugin, "SLSProject"),
		Endpoint:        output.FLBPluginConfigKey(plugin, "SLSEndPoint"),
		AccessKeyID:     output.FLBPluginConfigKey(plugin, "AccessKeyID"),
		AccessKeySecret: output.FLBPluginConfigKey(plugin, "AccessKeySecret"),
	}

	storeKey := output.FLBPluginConfigKey(plugin, "SLSLogStore")
	//matchKey := output.FLBPluginConfigKey(plugin, "Match")
	store, err := project.GetLogStore(storeKey)

	if err != nil {
		fmt.Printf("[error] GetLogStore [%s] failed: %v", storeKey, err)
		return output.FLB_ERROR
	}

	output.FLBPluginSetContext(plugin, store)
	return output.FLB_OK
}

//export FLBPluginFlushCtx
func FLBPluginFlushCtx(ctx, data unsafe.Pointer, length C.int, tag *C.char) int {
	// Gets called with a batch of records to be written to an instance.
	var store *sls.LogStore
	if store0 := output.FLBPluginGetContext(ctx); store0 == nil {
		fmt.Printf("[error] alisls store is nil")
		return output.FLB_ERROR
	} else if store1, ok := store0.(*sls.LogStore); !ok {
		fmt.Printf("[error] alisls store is err")
		return output.FLB_ERROR
	} else {
		store = store1
	}

	logs := []*sls.Log{}
	dec := output.NewDecoder(data, int(length))
	for {
		ret, ts, record := output.GetRecord(dec)
		if ret != 0 {
			break
		}

		var current time.Time
		switch t := ts.(type) {
		case output.FLBTime:
			current = ts.(output.FLBTime).Time
		case uint64:
			current = time.Unix(int64(t), 0)
		default:
			fmt.Println("[warn] unknown timestamp format.")
			current = time.Now()
		}

		idx := 0
		contents := make([]*sls.LogContent, len(record))
		for k, v := range record {
			k, _ := k.(string)
			content := &sls.LogContent{
				Key: proto.String(k),
			}

			switch t := v.(type) {
			case string:
				content.Value = proto.String(t)
			case []byte:
				content.Value = proto.String(string(t))
			default:
				content.Value = proto.String(fmt.Sprintf("%v", v))
			}

			contents[idx] = content
			idx += 1
		}

		l := &sls.Log{
			Time:     proto.Uint32(uint32(current.Unix())),
			Contents: contents,
		}
		logs = append(logs, l)
	}

	if len(logs) == 0 {
		return output.FLB_OK
	}

	group := &sls.LogGroup{
		Topic:  proto.String(C.GoString(tag)),
		Source: proto.String(hostname),
		Logs:   logs,
	}

	// todo body 5M limit
	if err := store.PutLogs(group); err != nil {
		fmt.Printf("[error] logsotre [%s] putlogs [%d] fail, err: %s\n", store.Name, len(logs), err)
		return output.FLB_ERROR
	}

	return output.FLB_OK
}

//export FLBPluginExit
func FLBPluginExit() int {
	return output.FLB_OK
}

func main() {
}
