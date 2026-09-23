package kr.sw4u.judge_app

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * Android 15(SDK 35)부터 앱은 상태바·내비게이션바 뒤까지 그린다(edge-to-edge).
 *
 * Flutter 는 인셋을 MediaQuery 로 넘겨주므로 화면 쪽(SafeArea·AppBar·하단 바)이
 * 알아서 비켜 그린다. 여기서는 플레이 콘솔이 요구하는 대로 [enableEdgeToEdge] 를
 * 명시적으로 호출해, 15 미만 기기에서도 같은 모양이 나오게 하고 "인셋 미처리" 경고를
 * 없앤다. [enableEdgeToEdge] 는 ComponentActivity 확장이라 FlutterActivity(=Activity)
 * 에서는 부를 수 없어 FlutterFragmentActivity 를 쓴다.
 */
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
